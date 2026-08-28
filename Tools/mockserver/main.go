package main

import (
	"crypto/sha1"
	"encoding/base32"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"time"
)

const (
	rpcPath             = "/transmission/rpc"
	sessionHeader       = "X-Transmission-Session-Id"
	defaultSessionID    = "seedtruck-mock"
	maximumTorrentBytes = 16 << 20
	// Base64 and JSON slash escaping can expand a maximum-size torrent past 40 MiB.
	maximumRequestBytes = 64 << 20
)

type rpcRequest struct {
	JSONRPC string          `json:"jsonrpc"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params"`
	ID      json.RawMessage `json:"id"`
}

type rpcResponse struct {
	JSONRPC string          `json:"jsonrpc"`
	Result  any             `json:"result,omitempty"`
	Error   *rpcError       `json:"error,omitempty"`
	ID      json.RawMessage `json:"id"`
}

type rpcError struct {
	Code    int           `json:"code"`
	Message string        `json:"message"`
	Data    *rpcErrorData `json:"data,omitempty"`
}

type rpcErrorData struct {
	ErrorString string `json:"error_string,omitempty"`
}

type torrent struct {
	ID                 int      `json:"id"`
	HashString         string   `json:"hash_string"`
	Name               string   `json:"name"`
	PercentDone        float64  `json:"percent_done"`
	RecheckProgress    float64  `json:"recheck_progress"`
	Status             int      `json:"status"`
	SizeWhenDone       int64    `json:"size_when_done"`
	PeersConnected     int      `json:"peers_connected"`
	RateUpload         int      `json:"rate_upload"`
	PeersSendingToUs   int      `json:"peers_sending_to_us"`
	PeersGettingFromUs int      `json:"peers_getting_from_us"`
	RateDownload       int      `json:"rate_download"`
	UploadedEver       int64    `json:"uploaded_ever"`
	DownloadedEver     int64    `json:"downloaded_ever"`
	UploadRatio        float64  `json:"upload_ratio"`
	SecondsDownloading int64    `json:"seconds_downloading"`
	SecondsSeeding     int64    `json:"seconds_seeding"`
	QueuePosition      int      `json:"queue_position"`
	ETA                int64    `json:"eta"`
	ETAIdle            int64    `json:"eta_idle"`
	Labels             []string `json:"labels"`
}

type speedLimits struct {
	Download        int  `json:"speed_limit_down"`
	Upload          int  `json:"speed_limit_up"`
	DownloadEnabled bool `json:"speed_limit_down_enabled"`
	UploadEnabled   bool `json:"speed_limit_up_enabled"`
}

type mockServer struct {
	mu        sync.Mutex
	sessionID string
	torrents  []torrent
	nextID    int
	limits    speedLimits
}

func newMockServer() *mockServer {
	return &mockServer{
		sessionID: defaultSessionID,
		torrents: []torrent{
			{
				ID: 1, HashString: "dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c",
				Name: "Big Buck Bunny", PercentDone: 0.58, Status: 4,
				SizeWhenDone: 8_400_000_000, PeersConnected: 24,
				RateDownload: 2_448_765, RateUpload: 125_000,
				PeersSendingToUs: 8, PeersGettingFromUs: 3,
				DownloadedEver: 4_872_000_000, UploadedEver: 1_250_000_000,
				UploadRatio: 0.26, SecondsDownloading: 7_200,
				QueuePosition: 0, ETA: 1_845, ETAIdle: -1,
				Labels: []string{"Movies", "Open source"},
			},
			{
				ID: 2, HashString: "257b501b9d8aef4537e0e0a7c6f2ff87f50c7f5a",
				Name: "Cosmos Laundromat", PercentDone: 0.72,
				RecheckProgress: 0.35, Status: 2, SizeWhenDone: 2_100_000_000,
				PeersConnected: 7, DownloadedEver: 1_512_000_000,
				QueuePosition: 1, ETA: -2, ETAIdle: -1,
				Labels: []string{"Animation"},
			},
			{
				ID: 3, HashString: "209c8226b299b308beaf2b9cd3fb49212dbd13ec",
				Name: "Tears of Steel", PercentDone: 1, Status: 6,
				SizeWhenDone: 3_750_000_000, PeersConnected: 8,
				RateUpload: 850_000, PeersGettingFromUs: 4,
				DownloadedEver: 3_750_000_000, UploadedEver: 9_000_000_000,
				UploadRatio: 2.4, SecondsSeeding: 3_600,
				QueuePosition: 2, ETA: -1, ETAIdle: 900,
				Labels: []string{"Movies"},
			},
			{
				ID: 4, HashString: "08ada5a7a6183aae1e09d831df6748d566095a10",
				Name: "Sintel", PercentDone: 0.43, Status: 0,
				SizeWhenDone: 4_000_000_000, DownloadedEver: 1_720_000_000,
				QueuePosition: 3, ETA: -1, ETAIdle: -1,
				Labels: []string{"Archive"},
			},
		},
		nextID: 5,
		limits: speedLimits{
			Download: 1_000, Upload: 500,
			DownloadEnabled: true, UploadEnabled: false,
		},
	}
}

func (s *mockServer) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != rpcPath {
		http.NotFound(w, r)
		return
	}
	if r.Method != http.MethodPost {
		w.Header().Set("Allow", http.MethodPost)
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	if r.Header.Get(sessionHeader) != s.sessionID {
		w.Header().Set(sessionHeader, s.sessionID)
		w.WriteHeader(http.StatusConflict)
		return
	}

	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, maximumRequestBytes))
	if err != nil {
		http.Error(w, "request body is too large", http.StatusRequestEntityTooLarge)
		return
	}

	var request rpcRequest
	if err := json.Unmarshal(body, &request); err != nil {
		s.writeError(w, nil, -32700, "Parse error", err.Error())
		return
	}
	if request.JSONRPC != "2.0" || request.Method == "" || len(request.ID) == 0 || string(request.ID) == "null" {
		s.writeError(w, request.ID, -32600, "Invalid Request", "Expected a JSON-RPC 2.0 request with a method and id")
		return
	}

	result, rpcErr := s.dispatch(request.Method, request.Params)
	if rpcErr != nil {
		s.writeResponse(w, rpcResponse{JSONRPC: "2.0", Error: rpcErr, ID: request.ID})
		return
	}
	s.writeResponse(w, rpcResponse{JSONRPC: "2.0", Result: result, ID: request.ID})
}

func (s *mockServer) dispatch(method string, rawParams json.RawMessage) (any, *rpcError) {
	s.mu.Lock()
	defer s.mu.Unlock()

	switch method {
	case "torrent_get":
		var params struct {
			Fields []string `json:"fields"`
			IDs    []int    `json:"ids"`
		}
		if err := decodeParams(rawParams, &params); err != nil {
			return nil, invalidParams(err)
		}

		selected := make([]torrent, 0, len(s.torrents))
		if len(params.IDs) == 0 {
			selected = append(selected, s.torrents...)
		} else {
			ids := make(map[int]struct{}, len(params.IDs))
			for _, id := range params.IDs {
				ids[id] = struct{}{}
			}
			for _, item := range s.torrents {
				if _, ok := ids[item.ID]; ok {
					selected = append(selected, item)
				}
			}
		}
		return struct {
			Torrents []map[string]any `json:"torrents"`
		}{Torrents: projectTorrentFields(selected, params.Fields)}, nil

	case "torrent_add":
		var params struct {
			Filename string   `json:"filename"`
			Metainfo string   `json:"metainfo"`
			Labels   []string `json:"labels"`
		}
		if err := decodeParams(rawParams, &params); err != nil {
			return nil, invalidParams(err)
		}
		if (params.Filename == "") == (params.Metainfo == "") {
			return nil, invalidParams(errors.New("provide exactly one of filename or metainfo"))
		}

		name := magnetName(params.Filename)
		var hash string
		if params.Metainfo != "" {
			metainfo, err := base64.StdEncoding.DecodeString(params.Metainfo)
			if err != nil {
				return nil, invalidParams(errors.New("metainfo is not valid base64"))
			}
			hash, err = torrentInfoHash(metainfo)
			if err != nil {
				return nil, invalidParams(fmt.Errorf("metainfo is not a valid torrent: %w", err))
			}
			name = "Uploaded torrent"
		} else {
			hash = magnetInfoHash(params.Filename)
			if hash == "" {
				return nil, invalidParams(errors.New("filename is not a magnet with a valid BitTorrent info hash"))
			}
		}
		for _, item := range s.torrents {
			if item.HashString == hash {
				return torrentAddResult("torrent_duplicate", item), nil
			}
		}

		added := torrent{
			ID: s.nextID, HashString: hash, Name: name,
			Status: 4, SizeWhenDone: 1_000_000_000,
			RateDownload: 1_500_000, PeersConnected: 6,
			PeersSendingToUs: 4, QueuePosition: len(s.torrents),
			ETA: 667, ETAIdle: -1, Labels: append([]string(nil), params.Labels...),
		}
		s.nextID++
		s.torrents = append(s.torrents, added)
		return torrentAddResult("torrent_added", added), nil

	case "torrent_start", "torrent_stop":
		var params struct {
			IDs []int `json:"ids"`
		}
		if err := decodeParams(rawParams, &params); err != nil {
			return nil, invalidParams(err)
		}
		for index := range s.torrents {
			if !contains(params.IDs, s.torrents[index].ID) {
				continue
			}
			if method == "torrent_stop" {
				s.torrents[index].Status = 0
				s.torrents[index].RateDownload = 0
				s.torrents[index].RateUpload = 0
				continue
			}
			if s.torrents[index].PercentDone >= 1 {
				s.torrents[index].Status = 6
				s.torrents[index].RateUpload = 250_000
			} else {
				s.torrents[index].Status = 4
				s.torrents[index].RateDownload = 1_500_000
			}
		}
		return struct{}{}, nil

	case "torrent_remove":
		var params struct {
			IDs             []int `json:"ids"`
			DeleteLocalData bool  `json:"delete_local_data"`
		}
		if err := decodeParams(rawParams, &params); err != nil {
			return nil, invalidParams(err)
		}
		kept := s.torrents[:0]
		for _, item := range s.torrents {
			if !contains(params.IDs, item.ID) {
				kept = append(kept, item)
			}
		}
		s.torrents = kept
		for index := range s.torrents {
			s.torrents[index].QueuePosition = index
		}
		return struct{}{}, nil

	case "session_get":
		return s.limits, nil

	case "session_set":
		var params speedLimits
		if err := decodeParams(rawParams, &params); err != nil {
			return nil, invalidParams(err)
		}
		if params.Download < 0 || params.Upload < 0 {
			return nil, invalidParams(errors.New("speed limits cannot be negative"))
		}
		s.limits = params
		return struct{}{}, nil

	default:
		return nil, &rpcError{Code: -32601, Message: "Method not found"}
	}
}

func decodeParams(raw json.RawMessage, destination any) error {
	if len(raw) == 0 || string(raw) == "null" {
		raw = json.RawMessage("{}")
	}
	return json.Unmarshal(raw, destination)
}

func invalidParams(err error) *rpcError {
	return &rpcError{
		Code: -32602, Message: "Invalid params",
		Data: &rpcErrorData{ErrorString: err.Error()},
	}
}

func torrentAddResult(key string, item torrent) map[string]any {
	return map[string]any{
		key: map[string]any{
			"hash_string": item.HashString,
			"id":          item.ID,
			"name":        item.Name,
		},
	}
}

func projectTorrentFields(torrents []torrent, fields []string) []map[string]any {
	projected := make([]map[string]any, 0, len(torrents))
	for _, item := range torrents {
		allFields := map[string]any{
			"id":                    item.ID,
			"hash_string":           item.HashString,
			"name":                  item.Name,
			"percent_done":          item.PercentDone,
			"recheck_progress":      item.RecheckProgress,
			"status":                item.Status,
			"size_when_done":        item.SizeWhenDone,
			"peers_connected":       item.PeersConnected,
			"rate_upload":           item.RateUpload,
			"peers_sending_to_us":   item.PeersSendingToUs,
			"peers_getting_from_us": item.PeersGettingFromUs,
			"rate_download":         item.RateDownload,
			"uploaded_ever":         item.UploadedEver,
			"downloaded_ever":       item.DownloadedEver,
			"upload_ratio":          item.UploadRatio,
			"seconds_downloading":   item.SecondsDownloading,
			"seconds_seeding":       item.SecondsSeeding,
			"queue_position":        item.QueuePosition,
			"eta":                   item.ETA,
			"eta_idle":              item.ETAIdle,
			"labels":                item.Labels,
		}
		selectedFields := make(map[string]any, len(fields))
		for _, field := range fields {
			if value, exists := allFields[field]; exists {
				selectedFields[field] = value
			}
		}
		projected = append(projected, selectedFields)
	}
	return projected
}

func magnetName(raw string) string {
	parsed, err := url.Parse(raw)
	if err == nil && parsed.Scheme == "magnet" {
		if name := strings.TrimSpace(parsed.Query().Get("dn")); name != "" {
			return name
		}
	}
	return "Added magnet"
}

func magnetInfoHash(raw string) string {
	parsed, err := url.Parse(raw)
	if err != nil || parsed.Scheme != "magnet" {
		return ""
	}
	for _, exactTopic := range parsed.Query()["xt"] {
		const prefix = "urn:btih:"
		if len(exactTopic) <= len(prefix) || !strings.EqualFold(exactTopic[:len(prefix)], prefix) {
			continue
		}
		encodedHash := exactTopic[len(prefix):]
		if decoded, err := hex.DecodeString(encodedHash); err == nil && len(decoded) == sha1.Size {
			return hex.EncodeToString(decoded)
		}
		decoder := base32.StdEncoding.WithPadding(base32.NoPadding)
		if decoded, err := decoder.DecodeString(strings.ToUpper(encodedHash)); err == nil && len(decoded) == sha1.Size {
			return hex.EncodeToString(decoded)
		}
	}
	return ""
}

func torrentInfoHash(metainfo []byte) (string, error) {
	if len(metainfo) == 0 || metainfo[0] != 'd' {
		return "", errors.New("top-level value is not a dictionary")
	}

	for offset := 1; ; {
		if offset >= len(metainfo) {
			return "", errors.New("unterminated top-level dictionary")
		}
		if metainfo[offset] == 'e' {
			return "", errors.New("missing info dictionary")
		}

		key, valueOffset, err := parseBencodeBytes(metainfo, offset)
		if err != nil {
			return "", err
		}
		valueEnd, err := skipBencodeValue(metainfo, valueOffset, 0)
		if err != nil {
			return "", err
		}
		if string(key) == "info" {
			digest := sha1.Sum(metainfo[valueOffset:valueEnd])
			return hex.EncodeToString(digest[:]), nil
		}
		offset = valueEnd
	}
}

func skipBencodeValue(data []byte, offset, depth int) (int, error) {
	if offset >= len(data) {
		return 0, errors.New("unexpected end of bencoded value")
	}
	if depth > 100 {
		return 0, errors.New("bencoded value is nested too deeply")
	}

	switch data[offset] {
	case 'i':
		end := offset + 1
		for end < len(data) && data[end] != 'e' {
			end++
		}
		if end == len(data) {
			return 0, errors.New("unterminated integer")
		}
		if _, err := strconv.ParseInt(string(data[offset+1:end]), 10, 64); err != nil {
			return 0, errors.New("invalid integer")
		}
		return end + 1, nil

	case 'l', 'd':
		isDictionary := data[offset] == 'd'
		offset++
		for {
			if offset >= len(data) {
				return 0, errors.New("unterminated collection")
			}
			if data[offset] == 'e' {
				return offset + 1, nil
			}
			if isDictionary {
				_, nextOffset, err := parseBencodeBytes(data, offset)
				if err != nil {
					return 0, err
				}
				offset = nextOffset
			}
			nextOffset, err := skipBencodeValue(data, offset, depth+1)
			if err != nil {
				return 0, err
			}
			offset = nextOffset
		}

	default:
		_, nextOffset, err := parseBencodeBytes(data, offset)
		return nextOffset, err
	}
}

func parseBencodeBytes(data []byte, offset int) ([]byte, int, error) {
	lengthEnd := offset
	for lengthEnd < len(data) && data[lengthEnd] >= '0' && data[lengthEnd] <= '9' {
		lengthEnd++
	}
	if lengthEnd == offset || lengthEnd >= len(data) || data[lengthEnd] != ':' {
		return nil, 0, errors.New("invalid byte string length")
	}
	length, err := strconv.Atoi(string(data[offset:lengthEnd]))
	if err != nil {
		return nil, 0, errors.New("invalid byte string length")
	}
	valueOffset := lengthEnd + 1
	valueEnd := valueOffset + length
	if valueEnd < valueOffset || valueEnd > len(data) {
		return nil, 0, errors.New("byte string exceeds input")
	}
	return data[valueOffset:valueEnd], valueEnd, nil
}

func contains(ids []int, target int) bool {
	for _, id := range ids {
		if id == target {
			return true
		}
	}
	return false
}

func (s *mockServer) writeError(w http.ResponseWriter, id json.RawMessage, code int, message, detail string) {
	if len(id) == 0 {
		id = json.RawMessage("null")
	}
	s.writeResponse(w, rpcResponse{
		JSONRPC: "2.0",
		Error: &rpcError{
			Code: code, Message: message,
			Data: &rpcErrorData{ErrorString: detail},
		},
		ID: id,
	})
}

func (s *mockServer) writeResponse(w http.ResponseWriter, response rpcResponse) {
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(response); err != nil {
		log.Printf("write response: %v", err)
	}
}

func main() {
	listenAddress := flag.String("listen", "127.0.0.1:9091", "address on which to listen")
	flag.Parse()

	server := &http.Server{
		Addr:              *listenAddress,
		Handler:           newMockServer(),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	log.Printf("Transmission mock listening at http://%s%s", *listenAddress, rpcPath)
	if err := server.ListenAndServe(); !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(fmt.Errorf("serve mock Transmission API: %w", err))
	}
}
