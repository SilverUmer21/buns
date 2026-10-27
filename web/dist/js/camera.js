/** Stable board camera: angle and framing affect presentation, never physics. */
export const CAMERA_MIN = 35;
export const CAMERA_MAX = 75;
export const CAMERA_DEFAULT = 52;
export function clampCameraAngle(value) {
  const n = Number(value);
  return Number.isFinite(n) ? Math.max(CAMERA_MIN, Math.min(CAMERA_MAX, n)) : CAMERA_DEFAULT;
}
export function fitBoardCamera(camera, angle, aspect) {
  const degrees = clampCameraAngle(angle);
  const radians = degrees * Math.PI / 180;
  const safeAspect = Math.max(0.1, Number.isFinite(aspect) ? aspect : 0.73);
  camera.position.set(0, 0.35 + 18 * Math.sin(radians), 18 * Math.cos(radians));
  camera.lookAt(0, 0.35, 0);
  // Include the rim and a generous allowance for a hopping bun. Width is
  // fitted independently so the tray never clips on narrow phone screens.
  const halfHeight = Math.max(4.08 / safeAspect, 5.65 * Math.sin(radians) + 1.12 * Math.cos(radians) + 0.45);
  camera.left = -halfHeight * safeAspect; camera.right = halfHeight * safeAspect;
  camera.top = halfHeight; camera.bottom = -halfHeight;
  camera.updateProjectionMatrix(); camera.updateMatrixWorld(true);
  return degrees;
}
