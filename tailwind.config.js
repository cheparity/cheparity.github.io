/** @type {import('tailwindcss').Config} */
export default {
  darkMode: 'class',
  content: ['./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}'],
  theme: {
    extend: {
      fontFamily: {
        sans: ['"Source Sans 3"', '"Helvetica Neue"', '"PingFang SC"', '"Hiragino Sans GB"', '"Microsoft YaHei"', '"微软雅黑"', 'sans-serif'],
        serif: ['et-book', 'Palatino', '"Palatino Linotype"', '"Palatino LT STD"', '"Book Antiqua"', 'Georgia', '"Songti SC"', '"Noto Serif CJK SC"', '"Source Han Serif SC"', 'SimSun', 'serif'],
      },
    },
  },
  plugins: [],
}
