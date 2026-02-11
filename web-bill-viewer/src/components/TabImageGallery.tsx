"use client";

import { useState } from "react";
import type { TabImage } from "@/lib/api";
import ImageLightbox from "./ImageLightbox";

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
      <div className="bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] rounded-2xl overflow-hidden shadow-sm mb-6">
        {/* Header */}
        <div className="px-6 py-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <i className="fas fa-camera text-[var(--primary)]" />
            <h2 className="font-semibold text-base">Receipts</h2>
          </div>
          <span className="text-xs font-medium text-[var(--text-secondary)] bg-[var(--secondary)] dark:bg-white/10 px-3 py-1 rounded-full">
            {processedCount}/{images.length} processed
          </span>
        </div>

        {/* Image grid */}
        <div className="px-6 pb-5 pt-1">
          <div className="grid grid-cols-3 gap-3">
            {images.map((image, index) => (
              <button
                key={image.id}
                onClick={() => setLightboxIndex(index)}
                className="relative aspect-square rounded-xl overflow-hidden group focus:outline-none focus:ring-2 focus:ring-[var(--primary)] focus:ring-offset-2"
              >
                <img
                  src={`${apiBaseUrl}${image.url}`}
                  alt={`Receipt ${index + 1}`}
                  className="w-full h-full object-cover transition-transform duration-300 group-hover:scale-105"
                />
                {/* Hover overlay */}
                <div className="absolute inset-0 bg-black/0 group-hover:bg-black/10 transition-colors duration-200" />
                {/* Processed badge */}
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

      {/* Lightbox */}
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
