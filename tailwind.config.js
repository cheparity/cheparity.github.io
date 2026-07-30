/** @type {import('tailwindcss').Config} */
export default {
  darkMode: 'class',
  content: ['./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}'],
  theme: {
    extend: {
      fontFamily: {
        serif: ['et-book', 'Palatino', '"Palatino Linotype"', '"Palatino LT STD"', '"Book Antiqua"', 'Georgia', 'serif'],
      },
    },
  },
  plugins: [],
}
