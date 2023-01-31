import * as fs from 'node:fs/promises'
import * as path from 'node:path'
import { retrieveDependencies } from '@sanjo/toc'
import * as child_process from 'node:child_process'

const buildDirectory = 'build'
await fs.rm(buildDirectory, {recursive: true, force: true})
await fs.mkdir(buildDirectory, {recursive: true})

const addOnName = 'CommodityBuyerAndSeller'

const dependenciesToCopy = await retrieveDependencies(`./${addOnName}/${addOnName}.toc`)
const dependenciesToCopySet = new Set(dependenciesToCopy)
for (let index = 0; index < dependenciesToCopy.length; index++) {
  const dependency = dependenciesToCopy[index]
  const dependencyPath = `AddOns/${dependency}`
  await fs.cp(dependencyPath, path.join(buildDirectory, dependency), {recursive: true})

  const dependencies2 = await retrieveDependencies(`${dependencyPath}/${dependency}.toc`)
  for (const dependency2 of dependencies2) {
    if (!dependenciesToCopySet.has(dependency2)) {
      dependenciesToCopySet.add(dependency2)
      dependenciesToCopy.push(dependency2)
    }
  }
}

await fs.cp(addOnName, `${buildDirectory}/${addOnName}`, {recursive: true})

const outputFileName = 'build.zip'
await fs.rm(outputFileName, {force: true})
child_process.execSync(`7z a -tzip ../${outputFileName} *`, {
  cwd: buildDirectory
})