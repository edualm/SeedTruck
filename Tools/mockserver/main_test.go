package main

import (
	"bytes"
	"crypto/sha1"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

type testRPCResponse struct {
	JSONRPC string          `json:"jsonrpc"`
	Result  json.RawMessage `json:"result"`
	Error   *rpcError       `json:"error"`
	ID      json.RawMessage `json:"id"`
}

func TestRequiresTransmissionSessionHeader(t *testing.T) {
	server := newMockServer()
	request := newRPCRequest(t, "torrent_get", map[string]any{"fields": []string{"id"}})
	recorder := httptest.NewRecorder()

	server.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusConflict {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusConflict)
	}
	if token := recorder.Header().Get(sessionHeader); token != defaultSessionID {
		t.Fatalf("session token = %q, want %q", token, defaultSessionID)
	}

	request = newRPCRequest(t, "torrent_get", map[string]any{"fields": []string{"id"}})
	request.Header.Set(sessionHeader, defaultSessionID)
	recorder = httptest.NewRecorder()
	server.ServeHTTP(recorder, request)

	response := decodeRPCResponse(t, recorder)
	if response.JSONRPC != "2.0" || string(response.ID) != `"request-1"` {
		t.Fatalf("unexpected response envelope: %+v", response)
	}
	var result struct {
		Torrents []map[string]any `json:"torrents"`
	}
	decodeResult(t, response, &result)
	if len(result.Torrents) == 0 || len(result.Torrents[0]) != 1 || result.Torrents[0]["id"] == nil {
		t.Fatalf("torrent_get did not honor requested fields: %+v", result.Torrents)
	}
}

func TestTorrentLifecycle(t *testing.T) {
	server := newMockServer()

	response := call(t, server, "torrent_add", map[string]any{
		"filename": "magnet:?xt=urn:btih:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa&dn=New+Fixture",
		"labels":   []string{"Test"},
	})
	var added struct {
		TorrentAdded struct {
			ID   int    `json:"id"`
			Name string `json:"name"`
		} `json:"torrent_added"`
	}
	decodeResult(t, response, &added)
	if added.TorrentAdded.Name != "New Fixture" {
		t.Fatalf("added name = %q, want %q", added.TorrentAdded.Name, "New Fixture")
	}

	call(t, server, "torrent_stop", map[string]any{"ids": []int{added.TorrentAdded.ID}})
	item := getTorrent(t, server, added.TorrentAdded.ID)
	if item.Status != 0 || item.RateDownload != 0 {
		t.Fatalf("stopped torrent = %+v", item)
	}

	call(t, server, "torrent_start", map[string]any{"ids": []int{added.TorrentAdded.ID}})
	item = getTorrent(t, server, added.TorrentAdded.ID)
	if item.Status != 4 || item.RateDownload == 0 {
		t.Fatalf("started torrent = %+v", item)
	}

	call(t, server, "torrent_remove", map[string]any{
		"ids":               []int{added.TorrentAdded.ID},
		"delete_local_data": true,
	})
	response = call(t, server, "torrent_get", map[string]any{
		"fields": []string{"id"},
		"ids":    []int{added.TorrentAdded.ID},
	})
	var result struct {
		Torrents []torrent `json:"torrents"`
	}
	decodeResult(t, response, &result)
	if len(result.Torrents) != 0 {
		t.Fatalf("removed torrent still returned: %+v", result.Torrents)
	}
}

func TestDuplicateTorrentAndMetainfoValidation(t *testing.T) {
	server := newMockServer()
	params := map[string]any{
		"filename": "magnet:?xt=urn:btih:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
	}
	call(t, server, "torrent_add", params)

	response := call(t, server, "torrent_add", params)
	var duplicate struct {
		TorrentDuplicate *struct {
			ID int `json:"id"`
		} `json:"torrent_duplicate"`
	}
	decodeResult(t, response, &duplicate)
	if duplicate.TorrentDuplicate == nil {
		t.Fatal("duplicate add did not return torrent_duplicate")
	}

	response = call(t, server, "torrent_add", map[string]any{"metainfo": "not base64"})
	if response.Error == nil || response.Error.Code != -32602 {
		t.Fatalf("invalid metainfo error = %+v", response.Error)
	}

	response = call(t, server, "torrent_add", map[string]any{
		"filename": "magnet:?xt=urn:btih:invalid",
	})
	if response.Error == nil || response.Error.Code != -32602 {
		t.Fatalf("invalid magnet error = %+v", response.Error)
	}
}

func TestUsesInfoHashForDuplicateDetection(t *testing.T) {
	server := newMockServer()
	infoDictionary := []byte("d4:name4:teste")
	metainfo := append([]byte("d4:info"), infoDictionary...)
	metainfo = append(metainfo, 'e')
	digest := sha1.Sum(infoDictionary)
	expectedHash := hex.EncodeToString(digest[:])

	response := call(t, server, "torrent_add", map[string]any{
		"metainfo": base64.StdEncoding.EncodeToString(metainfo),
	})
	var added struct {
		TorrentAdded struct {
			Hash string `json:"hash_string"`
		} `json:"torrent_added"`
	}
	decodeResult(t, response, &added)
	if added.TorrentAdded.Hash != expectedHash {
		t.Fatalf("hash = %q, want %q", added.TorrentAdded.Hash, expectedHash)
	}

	response = call(t, server, "torrent_add", map[string]any{
		"filename": "magnet:?xt=urn:btih:" + expectedHash + "&dn=Equivalent",
	})
	var duplicate struct {
		TorrentDuplicate any `json:"torrent_duplicate"`
	}
	decodeResult(t, response, &duplicate)
	if duplicate.TorrentDuplicate == nil {
		t.Fatal("equivalent magnet did not return torrent_duplicate")
	}
}

func TestCompactsQueuePositionsAfterRemoval(t *testing.T) {
	server := newMockServer()
	call(t, server, "torrent_remove", map[string]any{
		"ids":               []int{2},
		"delete_local_data": false,
	})

	response := call(t, server, "torrent_get", map[string]any{
		"fields": []string{"id", "queue_position"},
	})
	var result struct {
		Torrents []torrent `json:"torrents"`
	}
	decodeResult(t, response, &result)
	for index, item := range result.Torrents {
		if item.QueuePosition != index {
			t.Fatalf("torrent %d queue position = %d, want %d", item.ID, item.QueuePosition, index)
		}
	}
}

func TestAcceptsMaximumTorrentUploadRequest(t *testing.T) {
	worstCaseJSONBytes := 2*((maximumTorrentBytes+2)/3*4) + 1_024
	if maximumRequestBytes < worstCaseJSONBytes {
		t.Fatalf("request limit = %d, need at least %d for escaped base64", maximumRequestBytes, worstCaseJSONBytes)
	}

	server := newMockServer()
	request := newRPCRequest(t, "torrent_add", map[string]any{
		"metainfo": base64.StdEncoding.EncodeToString(make([]byte, maximumTorrentBytes)),
	})
	request.Header.Set(sessionHeader, defaultSessionID)
	recorder := httptest.NewRecorder()

	server.ServeHTTP(recorder, request)

	if recorder.Code == http.StatusRequestEntityTooLarge {
		t.Fatal("request body limit rejected Seed Truck's maximum torrent size")
	}
	response := decodeRPCResponse(t, recorder)
	if response.Error == nil || response.Error.Code != -32602 {
		t.Fatalf("zero-filled metainfo error = %+v", response.Error)
	}
}

func TestSessionSpeedLimits(t *testing.T) {
	server := newMockServer()
	wanted := speedLimits{
		Download: 2_000, Upload: 750,
		DownloadEnabled: false, UploadEnabled: true,
	}
	call(t, server, "session_set", wanted)

	response := call(t, server, "session_get", map[string]any{
		"fields": []string{
			"speed_limit_down", "speed_limit_up",
			"speed_limit_down_enabled", "speed_limit_up_enabled",
		},
	})
	var actual speedLimits
	decodeResult(t, response, &actual)
	if actual != wanted {
		t.Fatalf("limits = %+v, want %+v", actual, wanted)
	}
}

func call(t *testing.T, server http.Handler, method string, params any) testRPCResponse {
	t.Helper()
	request := newRPCRequest(t, method, params)
	request.Header.Set(sessionHeader, defaultSessionID)
	recorder := httptest.NewRecorder()
	server.ServeHTTP(recorder, request)
	return decodeRPCResponse(t, recorder)
}

func newRPCRequest(t *testing.T, method string, params any) *http.Request {
	t.Helper()
	body, err := json.Marshal(map[string]any{
		"jsonrpc": "2.0",
		"method":  method,
		"params":  params,
		"id":      "request-1",
	})
	if err != nil {
		t.Fatal(err)
	}
	return httptest.NewRequest(http.MethodPost, rpcPath, bytes.NewReader(body))
}

func decodeRPCResponse(t *testing.T, recorder *httptest.ResponseRecorder) testRPCResponse {
	t.Helper()
	if recorder.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", recorder.Code, recorder.Body.String())
	}
	var response testRPCResponse
	if err := json.Unmarshal(recorder.Body.Bytes(), &response); err != nil {
		t.Fatal(err)
	}
	return response
}

func decodeResult(t *testing.T, response testRPCResponse, destination any) {
	t.Helper()
	if response.Error != nil {
		t.Fatalf("unexpected RPC error: %+v", response.Error)
	}
	if err := json.Unmarshal(response.Result, destination); err != nil {
		t.Fatal(err)
	}
}

func getTorrent(t *testing.T, server http.Handler, id int) torrent {
	t.Helper()
	response := call(t, server, "torrent_get", map[string]any{
		"fields": []string{"id", "status", "rate_download"},
		"ids":    []int{id},
	})
	var result struct {
		Torrents []torrent `json:"torrents"`
	}
	decodeResult(t, response, &result)
	if len(result.Torrents) != 1 {
		t.Fatalf("torrent count = %d, want 1", len(result.Torrents))
	}
	return result.Torrents[0]
}
