package main

import (
	"benchmark/config"
	logInfra "benchmark/infrastructure/log"
	"benchmark/infrastructure/telemetry"
	"context"
	"encoding/json"
	"io/ioutil"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/reactivex/rxgo/v2"
	"github.com/sirupsen/logrus"
	log "github.com/sirupsen/logrus"
	ginlogrus "github.com/toorop/gin-logrus"
	"go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"
)

type CriptoPairs struct {
	Code string
	Url  string
}

type CriptoDetails struct {
	Details any   `json:"details"`
	Err     error `json:"error"`
}

type ReturnEvent struct {
	CriptoDetails []CriptoDetails `json:"details"`
}

var stocks = []CriptoPairs{
	{Code: "BTCLTC", Url: "https://api.n.exchange/en/api/v1/get_price/BTCLTC"},
}

var logger *logrus.Logger

func init() {
	logger = logrus.New()
	logger.SetReportCaller(true)
	logger.Formatter = &logrus.JSONFormatter{}
	log.SetOutput(logger.Writer())
}

func main() {

	logInfra.Setup()

	// Config telemetry
	tp, err := telemetry.Setup()
	if err != nil {
		panic(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	// Graceful shutdown and flush telemetry when the application exits.
	defer func(ctx context.Context) {
		// Do not make the application hang when it is shutdown.
		ctx, cancel = context.WithTimeout(ctx, time.Second*5)
		defer cancel()
		if err := tp.Shutdown(ctx); err != nil {
			panic(err)

		}
	}(ctx)

	// Routers
	r := gin.New()
	// Middlewares
	r.Use(ginlogrus.Logger(logger), gin.Recovery(), otelgin.Middleware("go-app"))
	r.GET("/metrics", gin.WrapH(promhttp.Handler())) // Prometheus metrics
	r.GET("/healthcheck", HealthCheck)
	r.GET("/ping", Ping)
	r.GET("/pairs", FetchPairs)
	r.GET("/config", Config)
	r.Run(config.ConfigObj.App.ServerAddress)
}

func HealthCheck(c *gin.Context) {
	res := map[string]any{
		"status": "up",
	}

	log.WithFields(log.Fields{
		"result": res,
	}).Info("Health check")

	c.JSON(http.StatusOK, res)
}

func Ping(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"message": "pong",
	})
}

func FetchPairs(c *gin.Context) {
	observable := rxgo.Just(stocks)()
	observable = observable.Map(func(_ context.Context, item any) (any, error) {
		su := item.(CriptoPairs)
		log.WithFields(log.Fields{
			"symbol": su.Code,
			"url":    su.Url,
		}).Info("Feching stock")
		details, err := fetchUrl(su.Url)
		if err != nil {
			log.WithFields(log.Fields{
				"symbol": su.Code,
				"url":    su.Url,
				"error":  err,
			}).Info("Error to fetch stock")
			return &CriptoDetails{Err: err}, nil
		}
		return &CriptoDetails{Details: details}, nil
	},
		rxgo.WithPool(5),
	)

	var stocksDetails []CriptoDetails
	for detailItem := range observable.Observe() {
		stocksDetails = append(stocksDetails, CriptoDetails{Details: detailItem.V, Err: detailItem.E})
	}

	payload := ReturnEvent{CriptoDetails: stocksDetails}

	log.WithFields(log.Fields{
		"payload": payload,
	}).Info("Respose")

	c.JSON(http.StatusOK, payload)
}

func fetchUrl(url string) (any, error) {
	log.WithFields(log.Fields{
		"url": url,
	}).Info("Feching url")

	client := http.Client{
		Timeout: time.Second * 2, // Timeout after 2 seconds
	}

	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		log.WithFields(log.Fields{
			"url":   url,
			"error": err,
		}).Error("Error on fetching url")
		return nil, err
	}

	res, err := client.Do(req)
	if err != nil {
		log.WithFields(log.Fields{
			"url":   url,
			"error": err,
		}).Error("Error on fetching url")
		return nil, err
	}

	if res.Body != nil {
		defer res.Body.Close()
	}

	body, err := ioutil.ReadAll(res.Body)
	if err != nil {
		log.WithFields(log.Fields{
			"url":   url,
			"error": err,
		}).Error("Error on fetching url")
		return nil, err
	}

	result := make(map[string]any)
	if err := json.Unmarshal(body, &result); err != nil {
		log.WithFields(log.Fields{
			"url":   url,
			"error": err,
		}).Error("Error on fetching url")
		return nil, err
	}
	log.WithFields(log.Fields{
		"url":      url,
		"response": result,
	}).Info("Result of fetch")
	return result, nil
}

func Config(c *gin.Context) {
	c.JSON(http.StatusOK, config.ConfigObj)
}
