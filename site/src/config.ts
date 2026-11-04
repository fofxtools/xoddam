/** Site-wide settings. Change them here; every page reads them. */
export const SITE = {
  name: 'Xoddam the Mighty',
  url: 'https://xoddam.com',
  tagline: 'Become a T-Rex. Save the puppies.',
  description:
    'Xoddam the Mighty is a free platformer for tablets, phones and keyboards. Run, jump, turn into a T-Rex and free the puppies the aliens have caged.',
  /** Google Analytics 4 measurement ID. Set to undefined to leave the tag out. */
  gaId: 'G-1ZY6WH7FEM',
  /** Where the game lives (the built game is copied here by scripts/copy-game.mjs). */
  playPath: '/play/',
  updated: '2026-11-04',
  /** The Android app (scripts/copy-apk.mjs copies the built file here). */
  android: { path: '/download/xoddam.apk' },
};
