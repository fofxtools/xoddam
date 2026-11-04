import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  // Canonical URLs, social previews and the sitemap all come from this one value.
  site: 'https://xoddam.com',
  // One URL per page: every internal link ends in "/".
  trailingSlash: 'always',
  // Astro 7 would otherwise drop the space before a link that starts on a new line ("Made withGodot").
  compressHTML: true,
  // The game page (/play/) is not an Astro page (scripts/copy-game.mjs adds it), so it is listed here by hand.
  integrations: [sitemap({ filter: (page) => !page.endsWith('/404/'), customPages: ['https://xoddam.com/play/'] })],
});
