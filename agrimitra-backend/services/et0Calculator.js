/**
 * Hargreaves equation for reference evapotranspiration (ET0)
 * ET0 = 0.0023 * (Tmean + 17.8) * sqrt(Tmax - Tmin) * Ra
 *
 * Tmean, Tmax, Tmin -> in degrees Celsius
 * Ra -> extraterrestrial radiation (MJ/m^2/day), depends on latitude + day of year
 */

function calculateRa(latitudeDegrees, dayOfYear) {
  const lat = (latitudeDegrees * Math.PI) / 180; // convert to radians

  const dr = 1 + 0.033 * Math.cos((2 * Math.PI * dayOfYear) / 365);
  const solarDeclination = 0.409 * Math.sin((2 * Math.PI * dayOfYear) / 365 - 1.39);

  const sunsetHourAngle = Math.acos(-Math.tan(lat) * Math.tan(solarDeclination));

  const Gsc = 0.0820; // solar constant, MJ/m^2/min

  const Ra =
    ((24 * 60) / Math.PI) *
    Gsc *
    dr *
    (sunsetHourAngle * Math.sin(lat) * Math.sin(solarDeclination) +
      Math.cos(lat) * Math.cos(solarDeclination) * Math.sin(sunsetHourAngle));

  return Ra; // MJ/m^2/day
}

function calculateET0({ tMax, tMin, tMean, latitude, dayOfYear }) {
  const Ra = calculateRa(latitude, dayOfYear); // MJ/m^2/day
  const RaMm = Ra * 0.408; // convert to mm/day equivalent

  const ET0 = 0.0023 * (tMean + 17.8) * Math.sqrt(tMax - tMin) * RaMm;
  return { ET0: Number(ET0.toFixed(2)), Ra: Number(Ra.toFixed(2)) };
}

module.exports = { calculateET0, calculateRa };