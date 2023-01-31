import * as fs from 'node:fs/promises'
import * as path from 'node:path'

const directory = 'J:/Program Files (x86)/World of Warcraft'

await fs.rename(path.join(directory, '_retail_', 'Interface', 'AddOns'), path.join(directory, '_retail_', 'Interface', 'AddOns_'))
await fs.symlink(path.resolve(path.join('.', 'build')), path.join(directory, '_retail_', 'Interface', 'AddOns'), 'dir')
