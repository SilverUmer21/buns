import test from 'node:test';
import assert from 'node:assert/strict';
import { CAMERA_DEFAULT, clampCameraAngle, fitBoardCamera } from '../dist/js/camera.js';

test('camera angle settings reject invalid values and stay in the usable range', () => {
  assert.equal(CAMERA_DEFAULT, 45);
  assert.equal(clampCameraAngle(-100), 35);
  assert.equal(clampCameraAngle(200), 75);
  assert.equal(clampCameraAngle(NaN), CAMERA_DEFAULT);
  assert.equal(clampCameraAngle(52), 52);
});
test('all angles keep the tray width visible at phone and desktop aspect ratios', () => {
  for (const aspect of [.47, .73, 1, 1.8]) for (const angle of [35, 45, 52, 63, 75]) {
    const camera = {position:{set(x,y,z){this.x=x;this.y=y;this.z=z}}, lookAt(){},updateProjectionMatrix(){},updateMatrixWorld(){}};
    assert.equal(fitBoardCamera(camera,angle,aspect),angle);
    assert.ok(camera.right >= 4.08 && camera.left <= -4.08);
    assert.ok(camera.top > 0 && camera.bottom < 0 && camera.position.y > 0);
  }
});
