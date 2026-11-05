import type { MetadataRoute } from "next";
import { site } from "./(public)/site";

export default function sitemap(): MetadataRoute.Sitemap {
  return [{ url: site.origin }, { url: `${site.origin}/privacy-policy` }];
}
