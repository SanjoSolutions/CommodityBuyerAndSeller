import * as fs from 'node:fs/promises'
import * as path from 'node:path'

const directory = 'J:/Program Files (x86)/World of Warcraft'

await fs.rm(path.join(directory, '_retail_', 'Interface', 'AddOns'), {recursive: true})
await fs.rename(path.join(directory, '_retail_', 'Interface', 'AddOns_'), path.join(directory, '_retail_', 'Interface', 'AddOns'))
