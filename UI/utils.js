function map(value, fromMin, fromMax, toMin, toMax) {
  return ((value - fromMin) / (fromMax - fromMin)) * (toMax - toMin) + toMin;
}

function UUID() {
  if (crypto) {
    return crypto.randomUUID();
  }
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, function (c) {
    var r = (Math.random() * 16) | 0,
      v = c == "x" ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

function parseGameTime(baseTime) {
  // convert time from range 0-43200 to 9:00AM-9:00PM
  time = Math.floor(map(baseTime, 0, 43200, 540, 1260));
  let hours = Math.floor(time / 60);
  let ext = "AM";
  if (hours > 12) {
    hours = hours - 12;
    ext = "PM";
  }
  let minutes = Math.floor(time % 60);
  let timeStr = `${hours < 10 ? "0" : ""}${hours}:${
    minutes < 10 ? "0" : ""
  }${minutes} ${ext}`;
  return timeStr;
}