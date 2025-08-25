# Docker Compose for local development
version: '3.8'

services:
  mongodb:
    image: mongo:5.0
    container_name: filesure-mongodb
    ports:
      - "27017:27017"
    environment:
      - MONGO_INITDB_DATABASE=filesure
    volumes:
      - mongodb_data:/data/db
    networks:
      - filesure-network

  api:
    build:
      context: .
      dockerfile: api/Dockerfile
    container_name: filesure-api
    ports:
      - "5001:5001"
    environment:
      - MONGO_URI=mongodb://mongodb:27017
      - AZURE_BLOB_CONN=${AZURE_BLOB_CONN}
      - AZURE_CONTAINER=documents
    depends_on:
      - mongodb
    networks:
      - filesure-network
    volumes:
      - ./api:/app
    restart: unless-stopped

  worker:
    build:
      context: .
      dockerfile: worker/Dockerfile
    container_name: filesure-worker
    ports:
      - "9100:9100"
    environment:
      - MONGO_URI=mongodb://mongodb:27017
      - AZURE_BLOB_CONN=${AZURE_BLOB_CONN}
      - AZURE_CONTAINER=documents
      - JOB_ID=${JOB_ID}
    depends_on:
      - mongodb
    networks:
      - filesure-network
    volumes:
      - ./worker:/app
    restart: "no"  # Don't restart automatically for testing

volumes:
  mongodb_data:

networks:
  filesure-network:
    driver: bridge