// Simplified crop data: growth duration and FAO-style crop coefficients (Kc)
// for three stages. Not exhaustive — covers common crops for this project,
// with a sensible default for anything not listed.
const crops = {
  rice: { durationDays: 120, kc: { initial: 1.05, mid: 1.20, late: 0.90 } },
  maize: { durationDays: 100, kc: { initial: 0.30, mid: 1.20, late: 0.60 } },
  cotton: { durationDays: 180, kc: { initial: 0.35, mid: 1.15, late: 0.65 } },
  tomato: { durationDays: 100, kc: { initial: 0.60, mid: 1.15, late: 0.80 } },
  chickpea: { durationDays: 100, kc: { initial: 0.40, mid: 1.00, late: 0.35 } },
  banana: { durationDays: 300, kc: { initial: 0.50, mid: 1.10, late: 1.00 } },
  papaya: { durationDays: 270, kc: { initial: 0.50, mid: 1.05, late: 1.00 } },
  mango: { durationDays: 365, kc: { initial: 0.50, mid: 0.75, late: 0.75 } },
  coconut: { durationDays: 365, kc: { initial: 0.70, mid: 0.85, late: 0.85 } },
  ragi: { durationDays: 110, kc: { initial: 0.50, mid: 1.00, late: 0.60 } },
  groundnut: { durationDays: 120, kc: { initial: 0.40, mid: 1.05, late: 0.60 } },
};

const defaultCrop = { durationDays: 120, kc: { initial: 0.50, mid: 1.00, late: 0.70 } };

// Simplified stage boundaries as a fraction of total growth duration
const STAGE_BOUNDARIES = { initialEnd: 0.15, midEnd: 0.85 };

function getCropInfo(cropType) {
  return crops[cropType?.toLowerCase()] || defaultCrop;
}

// Given when the crop was planted, work out what growth stage it's in today,
// how many days until harvest, and the actual harvest date.
function computeGrowthStatus(cropType, plantingDate) {
  const info = getCropInfo(cropType);
  const planted = new Date(plantingDate);
  const today = new Date();

  const daysSincePlanting = Math.floor((today - planted) / (1000 * 60 * 60 * 24));
  const fraction = daysSincePlanting / info.durationDays;

  let stage;
  if (fraction < 0) stage = 'not_yet_planted';
  else if (fraction < STAGE_BOUNDARIES.initialEnd) stage = 'initial';
  else if (fraction < STAGE_BOUNDARIES.midEnd) stage = 'mid';
  else if (fraction < 1) stage = 'late';
  else stage = 'ready_for_harvest';

  const harvestDate = new Date(planted);
  harvestDate.setDate(harvestDate.getDate() + info.durationDays);

  const daysToHarvest = Math.ceil((harvestDate - today) / (1000 * 60 * 60 * 24));

  return {
    stage,
    daysSincePlanting,
    daysToHarvest,
    harvestDate,
    durationDays: info.durationDays,
    kc: info.kc
  };
}

module.exports = { getCropInfo, computeGrowthStatus, crops };