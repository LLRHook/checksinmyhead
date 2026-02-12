"use client";

import { useState } from "react";
import type { TabImage } from "@/lib/api";
import ImageLightbox from "./ImageLightbox";
import { FaCamera } from "react-icons/fa6";

interface TabImageGalleryProps {
  images: TabImage[];
  apiBaseUrl: string;
}

export default function TabImageGallery({
  images,
  apiBaseUrl,
}: TabImageGalleryProps) {
  const [lightboxIndex, setLightboxIndex] = useState<number | null>(null);
  const processedCount = images.filter((img) => img.processed).length;

  return (
    <>
      <div className="bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] rounded-2xl overflow-hidden shadow-sm dark:shadow-none dark:border dark:border-[var(--border-dark)] mb-6">
        <div className="px-5 py-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <FaCamera className="text-[var(--primary)]" size={14} />
            <h2 className="font-semibold text-base">Receipts</h2>
          </div>
          <span className="text-xs font-medium text-[var(--text-secondary)] bg-[var(--secondary)] dark:bg-white/10 px-3 py-1 rounded-full">
            {processedCount}/{images.length} processed
          </span>
        </div>

        <div className="px-5 pb-5 pt-1">
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
            {images.map((image, index) => (
              <button
                key={image.id}
                onClick={() => setLightboxIndex(index)}
                className="relative aspect-square rounded-xl overflow-hidden group focus:outline-none focus-visible:ring-2 focus-visible:ring-[var(--primary)] focus-visible:ring-offset-2"
              >
                <img
                  src={`${apiBaseUrl}${image.url}`}
                  alt={`Receipt ${index + 1}`}
                  className="w-full h-full object-cover transition-transform duration-200 group-hover:scale-105"
                />
                <div className="absolute inset-0 bg-black/0 group-hover:bg-black/10 transition-colors duration-200" />
                {image.processed && (
                  <div className="absolute top-2 right-2 w-6 h-6 bg-green-500 rounded-full flex items-center justify-center shadow-sm">
                    <svg
                      className="w-3.5 h-3.5 text-white"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      strokeWidth={3}
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        d="M5 13l4 4L19 7"
                      />
                    </svg>
                  </div>
                )}
              </button>
            ))}
          </div>
        </div>
      </div>

      {lightboxIndex !== null && (
        <ImageLightbox
          images={images}
          currentIndex={lightboxIndex}
          apiBaseUrl={apiBaseUrl}
          onClose={() => setLightboxIndex(null)}
          onNavigate={setLightboxIndex}
        />
      )}
    </>
  );
}
