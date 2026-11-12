import { readFileSync } from "node:fs";

type RGB = number[];
export const rgb = (hex: string): RGB =>
  [1, 3, 5].map((i) => Number.parseInt(hex.slice(i, i + 2), 16));
export const blend = (ink: RGB, surface: RGB, opacity: number) =>
  ink.map((v, i) => v * opacity + surface[i] * (1 - opacity));
const luminance = (color: RGB) =>
  color.reduce((sum, v, i) => {
    const s = v / 255;
    return (
      sum +
      [0.2126, 0.7152, 0.0722][i] *
        (s <= 0.04045 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4)
    );
  }, 0);
export const contrast = (ink: RGB, surface: RGB) => {
  const [lo, hi] = [luminance(ink), luminance(surface)].sort((a, b) => a - b);
  return (hi + 0.05) / (lo + 0.05);
};
export const css = readFileSync("src/app/globals.css", "utf8");
export const root = css.split("@media")[0];
export const dark = css.split("@media (prefers-color-scheme: dark)")[1];
export const token = (name: string, theme = root) =>
  rgb(theme.match(new RegExp(`--${name}:\\s*(#[0-9a-f]{6})`))?.[1] ?? "");
