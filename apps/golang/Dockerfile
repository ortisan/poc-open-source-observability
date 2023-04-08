FROM golang:1.20-alpine AS build
WORKDIR /app
COPY go.mod ./
COPY go.sum ./
RUN go mod download
COPY ./ ./
RUN go build -o main

FROM golang:1.20-alpine 
WORKDIR /app
RUN apk add ca-certificates
COPY --from=build /app/main ./
COPY config.yml ./

EXPOSE 8080
CMD [ "./main" ]