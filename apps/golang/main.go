package main

import (
	"benchmark/config"
	"benchmark/telemetry"
	"context"
	"encoding/json"
	"io/ioutil"
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/reactivex/rxgo/v2"
	"github.com/sirupsen/logrus"
	ginlogrus "github.com/toorop/gin-logrus"
	"go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"
)

type StockUrl struct {
	Code string
	Url  string
}

type StockDetails struct {
	Details any   `json:"details"`
	Err     error `json:"error"`
}

type ReturnEvent struct {
	StocksDetails []StockDetails `json:"stocksDetails"`
}

var stocks = []StockUrl{
	StockUrl{Code: "ITSA4.SA", Url: "https://query1.finance.yahoo.com/v7/finance/quote?symbols=ITSA4.SA&fields=exchangeTimezoneName,exchangeTimezoneShortName,regularMarketTime&region=US&lang=en-US"},
	StockUrl{Code: "PETR4.SA", Url: "https://query1.finance.yahoo.com/v7/finance/quote?symbols=PETR4.SA&fields=exchangeTimezoneName,exchangeTimezoneShortName,regularMarketTime&region=US&lang=en-US"},
	StockUrl{Code: "MGLU3.SA", Url: "https://query1.finance.yahoo.com/v7/finance/quote?symbols=MGLU3.SA&fields=exchangeTimezoneName,exchangeTimezoneShortName,regularMarketTime&region=US&lang=en-US"},
	StockUrl{Code: "VALE3.SA", Url: "https://query1.finance.yahoo.com/v7/finance/quote?symbols=VALE3.SA&fields=exchangeTimezoneName,exchangeTimezoneShortName,regularMarketTime&region=US&lang=en-US"},
	StockUrl{Code: "PRIO3.SA", Url: "https://query1.finance.yahoo.com/v7/finance/quote?symbols=PRIO3.SA&fields=exchangeTimezoneName,exchangeTimezoneShortName,regularMarketTime&region=US&lang=en-US"},
}

var logger *logrus.Logger

func init() {
	logger = logrus.New()
	logger.SetReportCaller(true)
	logger.Formatter = &logrus.JSONFormatter{}
	log.SetOutput(logger.Writer())
}

func main() {

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
	r.GET("/stocks", FetchStocks)
	r.Run(config.ConfigObj.App.ServerAddress)
}

func HealthCheck(c *gin.Context) {
	res := map[string]any{
		"status": "up",
	}
	c.JSON(http.StatusOK, res)
}

func Ping(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"message": "pong",
	})
}

func FetchStocks(c *gin.Context) {
	observable := rxgo.Just(stocks)()
	observable = observable.Map(func(_ context.Context, item any) (any, error) {
		su := item.(StockUrl)
		details, err := fetchUrl(su.Url)
		if err != nil {
			return &StockDetails{Err: err}, nil
		}
		return &StockDetails{Details: details}, nil
	},
		rxgo.WithPool(5),
	)

	var stocksDetails []StockDetails
	for detailItem := range observable.Observe() {
		stocksDetails = append(stocksDetails, StockDetails{Details: detailItem.V, Err: detailItem.E})
	}

	c.JSON(http.StatusOK, ReturnEvent{StocksDetails: stocksDetails})
}

func fetchUrl(url string) (any, error) {
	client := http.Client{
		Timeout: time.Second * 2, // Timeout after 2 seconds
	}

	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}

	res, err := client.Do(req)
	if err != nil {
		return nil, err
	}

	if res.Body != nil {
		defer res.Body.Close()
	}

	body, err := ioutil.ReadAll(res.Body)
	if err != nil {
		return nil, err
	}

	result := make(map[string]any)
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, err
	}

	return result, nil
}
