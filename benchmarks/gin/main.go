package main

import (
	"io"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
)

func main() {
	gin.SetMode(gin.ReleaseMode)

	port := os.Getenv("PORT")
	if port == "" {
		port = "3000"
	}

	router := gin.New()
	router.GET("/plaintext", func(c *gin.Context) {
		c.String(http.StatusOK, "Hello, World!")
	})
	router.GET("/json", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"message": "Hello, World!"})
	})
	router.GET("/echo/:name", func(c *gin.Context) {
		c.String(http.StatusOK, c.Param("name"))
	})
	router.POST("/echo", func(c *gin.Context) {
		c.Header("content-type", "application/octet-stream")
		_, _ = io.Copy(c.Writer, c.Request.Body)
	})

	if err := router.Run("0.0.0.0:" + port); err != nil {
		panic(err)
	}
}
