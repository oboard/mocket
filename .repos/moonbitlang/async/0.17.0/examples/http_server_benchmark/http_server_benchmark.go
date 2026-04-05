package main

import (
  "net/http"
)

func main() {
  http.HandleFunc("/", func (w http.ResponseWriter, r *http.Request) {
  })

  http.ListenAndServe(":3003", nil)
}
