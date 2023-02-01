import { build } from '@sanjo/add-on-builder'
import * as fs from 'node:fs/promises'

await build()

// For testing
const addOnName = 'CommodityBuyerAndSeller'
const buildDirectory = 'build'

const addOnsToCopy = [
  'CommoditiesBuyerAndSellerData',
  'TradeSkillMaster',
  'TradeSkillMaster_AppHelper',
  '!Swatter',
]

for (const addOnName of addOnsToCopy) {
  await fs.symlink(
    `E:/Users/jonas/Documents/World of Warcraft/_retail_/Interface/AddOns/${ addOnName }`,
    `${ buildDirectory }/${ addOnName }`,
    'dir',
  )
}

await fs.rm(`${ buildDirectory }/${ addOnName }`, { recursive: true })
await fs.symlink(
  `../${ addOnName }`,
  `${ buildDirectory }/${ addOnName }`,
  'dir',
)
