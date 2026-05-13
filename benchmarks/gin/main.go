package main

import (
	"fmt"
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
	noopMiddleware := func(c *gin.Context) {
		c.Next()
	}
	middlewareGroup := router.Group("/middleware", noopMiddleware)
	middlewareGroup.GET("/plaintext", func(c *gin.Context) {
		c.String(http.StatusOK, "Hello, World!")
	})
	for i := 0; i < 1000; i++ {
		router.GET(fmt.Sprintf("/static/%d", i), func(c *gin.Context) {
			c.String(http.StatusOK, "Hello, World!")
		})
	}
	router.GET("/plaintext", func(c *gin.Context) {
		c.String(http.StatusOK, "Hello, World!")
	})
	router.GET("/api/plaintext", func(c *gin.Context) {
		c.String(http.StatusOK, "Hello, World!")
	})
	router.GET("/api/v1/users/current/profile/settings", func(c *gin.Context) {
		c.String(http.StatusOK, "settings")
	})
	router.GET("/json", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"message": "Hello, World!"})
	})
	router.GET("/echo/:name", func(c *gin.Context) {
		c.String(http.StatusOK, c.Param("name"))
	})
	router.GET("/users/:userID/posts/:postID/comments/:commentID", func(c *gin.Context) {
		c.String(http.StatusOK, c.Param("commentID"))
	})
	router.GET("/wild/*path", func(c *gin.Context) {
		c.String(http.StatusOK, c.Param("path"))
	})
	router.GET("/query", func(c *gin.Context) {
		c.String(http.StatusOK, c.DefaultQuery("name", "moonbit"))
	})
	router.GET("/headers", func(c *gin.Context) {
		c.Header("x-benchmark", "gin")
		c.String(http.StatusOK, "ok")
	})
	router.POST("/echo", func(c *gin.Context) {
		c.Header("content-type", "application/octet-stream")
		_, _ = io.Copy(c.Writer, c.Request.Body)
	})
	router.POST("/json-echo", func(c *gin.Context) {
		c.Header("content-type", "application/json; charset=utf-8")
		_, _ = io.Copy(c.Writer, c.Request.Body)
	})
	router.POST("/consume", func(c *gin.Context) {
		_, _ = io.Copy(io.Discard, c.Request.Body)
		c.String(http.StatusOK, "ok")
	})

	if err := router.Run("0.0.0.0:" + port); err != nil {
		panic(err)
	}
}
