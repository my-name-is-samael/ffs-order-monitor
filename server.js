const fs = require("fs");
const path = require("path");
const express = require("express");
const app = express();
const http = require('http');
const server = http.createServer(app);
const { Server } = require("socket.io");
const io = new Server(server);
const port = 30001;

// Web Server part
app.use(express.json());
app.use("/UI", express.static("UI"));

app.get("/", (req, res) => {
  res.sendFile("OrdersMonitor.html", { root: __dirname });
});

app.get("/events_export.js", (req, res) => {
  res.send(eventsCache);
});

app.get("/orders_export.js", (req, res) => {
  res.send(ordersCache);
});

// add a delay to the server start to ensure the events and orders are loaded
setTimeout(() => {
  server.listen(port, () => {
    console.log(`OrdersMonitor listening on port ${port}`);
  });
}, 500);

io.on("connection", (socket) => {
  const ipAddress = socket.handshake.headers["x-forwarded-for"]?.split(",")[0] || socket.client.conn.remoteAddress;
  console.log(`user connected from ${ipAddress}`);
  socket.emit("orders_update", ordersArray);
  socket.emit("events_update", eventsArray);
  socket.on('disconnect', () => {
    console.log(`user disconnected from ${ipAddress}`);
  });
});

// File change monitor part
// monitor events_export.js and orders_export.js change on local folder
const events_export_path = path.join(__dirname, "events_export.js");
const orders_export_path = path.join(__dirname, "orders_export.js");

let eventsCache = fs.readFileSync(events_export_path, "utf8");
let eventsArray = [];
let ordersCache = fs.readFileSync(orders_export_path, "utf8");
let ordersArray = [];

// fs.watch(path.join(__dirname, "events_export.js"), (event, filename) => {
fs.watch(events_export_path, (event, filename) => {
  const newEventsCache = fs.readFileSync(events_export_path, "utf8");
  if (newEventsCache.length > 0 && eventsCache !== newEventsCache) {
    eventsCache = newEventsCache;
    // parse eventsCache to eventsArray
    const newEventsTrim = eventsCache.substring(31, eventsCache.length - 3);
    eventsArray = JSON.parse(newEventsTrim);
    io.emit("events_update", eventsArray);
  }
});

// fs.watch(path.join(__dirname, "orders_export.js"), (event, filename) => {
fs.watch(orders_export_path, (event, filename) => {
  const newOrdersCache = fs.readFileSync(orders_export_path, "utf8");
  if (newOrdersCache.length > 0 && ordersCache !== newOrdersCache) {
    ordersCache = newOrdersCache;
    // parse ordersCache to ordersArray
    const newOrdersTrim = ordersCache.substring(31, ordersCache.length - 3);
    ordersArray = JSON.parse(newOrdersTrim);
    io.emit("orders_update", ordersArray);
  }
});

function initEvents() {
  const eventsTrim = eventsCache.substring(31, eventsCache.length - 3);
  eventsArray = JSON.parse(eventsTrim);
  console.log(`${eventsArray.length} events loaded`);
  
}

function initOrders() {
  const ordersTrim = ordersCache.substring(31, ordersCache.length - 3);
  ordersArray = JSON.parse(ordersTrim);
  console.log(`${ordersArray.length} orders loaded`);
}

initEvents();
initOrders();
