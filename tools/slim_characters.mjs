// Dev tool: prepares a KayKit character for the game.
// Strips unused animations and accessories, then joins every part into one skinned mesh per
// material, so a zombie costs one draw call instead of six or more.
// Usage: node slim_characters.mjs <input.glb> <output.glb> [extra rigid part to keep ...]
// Rigid parts (a hat, a staff) are bound to the bone they hang from and joined as well.
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { prune, dedup, joinPrimitives } from '@gltf-transform/functions';

const KEEP_ANIMS = new Set(['Idle', 'Walking_A', 'Walking_C', 'Running_A', 'Unarmed_Melee_Attack_Punch_A',
  '1H_Melee_Attack_Chop', '2H_Ranged_Shoot', 'Spellcast_Shoot', 'PickUp', 'Hit_A', 'Death_A', 'Death_B']);
const [input, output, ...extra] = process.argv.slice(2);
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const doc = await io.read(input);
const root = doc.getRoot();
for (const a of root.listAnimations()) if (!KEEP_ANIMS.has(a.getName())) a.dispose();
for (const n of root.listNodes()) {
  if (n.getMesh() && !n.getSkin() && !extra.includes(n.getName())) n.dispose();
  else if (n.getName().endsWith('_Cape') && !extra.includes(n.getName())) n.dispose();
}
const skin = root.listSkins()[0];
const joints = skin.listJoints();

function mulPoint(m, p) {
  return [m[0] * p[0] + m[4] * p[1] + m[8] * p[2] + m[12],
    m[1] * p[0] + m[5] * p[1] + m[9] * p[2] + m[13],
    m[2] * p[0] + m[6] * p[1] + m[10] * p[2] + m[14]];
}
function mulDir(m, d) {
  const v = [m[0] * d[0] + m[4] * d[1] + m[8] * d[2], m[1] * d[0] + m[5] * d[1] + m[9] * d[2], m[2] * d[0] + m[6] * d[1] + m[10] * d[2]];
  const l = Math.hypot(...v) || 1;
  return v.map((c) => c / l);
}

const skinned = root.listNodes().find((n) => n.getMesh() && n.getSkin()).getMesh().listPrimitives()[0];
const sampleJoints = skinned.getAttribute('JOINTS_0');
const sampleWeights = skinned.getAttribute('WEIGHTS_0');

// Rigid parts: bake the rest pose into the vertices and bind them fully to their parent bone.
for (const n of root.listNodes()) {
  const mesh = n.getMesh();
  if (!mesh || n.getSkin()) continue;
  let parent = n.getParentNode();
  while (parent && !joints.includes(parent)) parent = parent.getParentNode();
  if (!parent) throw new Error('no bone above ' + n.getName());
  const jointIndex = joints.indexOf(parent);
  const m = n.getWorldMatrix();
  for (const prim of mesh.listPrimitives()) {
    const pos = prim.getAttribute('POSITION');
    const nor = prim.getAttribute('NORMAL');
    const count = pos.getCount();
    const j = new (sampleJoints.getArray().constructor)(count * 4);
    const w = new (sampleWeights.getArray().constructor)(count * 4);
    for (let i = 0; i < count; i++) {
      pos.setElement(i, mulPoint(m, pos.getElement(i, [])));
      if (nor) nor.setElement(i, mulDir(m, nor.getElement(i, [])));
      j[i * 4] = jointIndex;
      w[i * 4] = sampleWeights.getNormalized() ? 255 : 1;
    }
    prim.setAttribute('JOINTS_0', doc.createAccessor().setType('VEC4').setArray(j).setBuffer(pos.getBuffer()));
    prim.setAttribute('WEIGHTS_0', doc.createAccessor().setType('VEC4').setArray(w).setNormalized(sampleWeights.getNormalized()).setBuffer(pos.getBuffer()));
  }
  n.setSkin(skin).setTranslation([0, 0, 0]).setRotation([0, 0, 0, 1]).setScale([1, 1, 1]);
  n.getParentNode()?.removeChild(n);
  root.listScenes()[0].addChild(n);
}

// Join everything that shares a material.
const groups = new Map();
for (const n of root.listNodes()) {
  const mesh = n.getMesh();
  if (!mesh) continue;
  for (const prim of mesh.listPrimitives()) {
    const key = prim.getMaterial();
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(prim);
  }
}
const firstMeshNode = root.listNodes().find((n) => n.getMesh());
const holder = firstMeshNode.getParentNode();
const joined = doc.createMesh('body');
for (const [material, prims] of groups) {
  const p = joinPrimitives(prims);
  p.setMaterial(material);
  joined.addPrimitive(p);
}
for (const n of root.listNodes()) if (n.getMesh()) n.dispose();
const body = doc.createNode('body').setMesh(joined).setSkin(skin);
(holder ?? root.listScenes()[0]).addChild(body);

await doc.transform(prune({ keepLeaves: true, keepAttributes: true }), dedup());
await io.write(output, doc);
console.log(output, root.listAnimations().length, 'animations,', joined.listPrimitives().length, 'surfaces');
