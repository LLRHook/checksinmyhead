"use client";

import Image from "next/image";
import { useCallback, useEffect } from "react";
import { FaChevronLeft, FaChevronRight, FaXmark } from "react-icons/fa6";
import type { TabImage } from "@/lib/api";

interface ImageLightboxProps {
  images: TabImage[];
  currentIndex: number;
  apiBaseUrl: string;
  onClose: () => void;
  onNavigate: (index: number) => void;
}

export default function ImageLightbox({
  images,
  currentIndex,
  apiBaseUrl,
  onClose,
  onNavigate,
}: ImageLightboxProps) {
  const image = images[currentIndex];

  const handleKeyDown = useCallback(
    (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
      if (e.key === "ArrowLeft" && currentIndex > 0)
        onNavigate(currentIndex - 1);
      if (e.key === "ArrowRight" && currentIndex < images.length - 1)
        onNavigate(currentIndex + 1);
    },
    [currentIndex, images.length, onClose, onNavigate],
  );

  useEffect(() => {
    document.addEventListener("keydown", handleKeyDown);
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", handleKeyDown);
      document.body.style.overflow = "";
    };
  }, [handleKeyDown]);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      <button
        type="button"
        aria-label="Close image viewer"
        className="absolute inset-0 bg-black/90"
        onClick={onClose}
      />
      <div className="relative z-10 max-w-5xl w-full h-full flex flex-col items-center justify-center px-4">
        {/* Header */}
        <div className="absolute top-0 left-0 right-0 flex items-center justify-between p-4 z-10">
          <div className="flex items-center gap-3">
            <span className="text-white/70 text-sm font-medium">
              {currentIndex + 1} / {images.length}
            </span>
            {image.processed && (
              <span className="px-2.5 py-1 bg-green-500/90 text-white text-xs font-semibold rounded-full">
                Processed
              </span>
            )}
          </div>
          <button
            type="button"
            onClick={onClose}
            className="w-10 h-10 flex items-center justify-center rounded-full bg-white/10 hover:bg-white/20 transition-colors"
            aria-label="Close image viewer"
          >
            <FaXmark className="w-5 h-5 text-white" />
          </button>
        </div>

        {/* Image */}
        <div className="relative h-[80vh] w-full">
          <Image
            src={`${apiBaseUrl}${image.url}`}
            alt={`Receipt ${currentIndex + 1}`}
            fill
            sizes="100vw"
            className="object-contain rounded-lg select-none"
            draggable={false}
          />
        </div>

        {/* Navigation arrows */}
        {currentIndex > 0 && (
          <button
            type="button"
            onClick={() => onNavigate(currentIndex - 1)}
            className="absolute left-4 top-1/2 -translate-y-1/2 w-12 h-12 flex items-center justify-center rounded-full bg-white/10 hover:bg-white/20 transition-colors"
            aria-label="Previous image"
          >
            <FaChevronLeft className="w-6 h-6 text-white" />
          </button>
        )}
        {currentIndex < images.length - 1 && (
          <button
            type="button"
            onClick={() => onNavigate(currentIndex + 1)}
            className="absolute right-4 top-1/2 -translate-y-1/2 w-12 h-12 flex items-center justify-center rounded-full bg-white/10 hover:bg-white/20 transition-colors"
            aria-label="Next image"
          >
            <FaChevronRight className="w-6 h-6 text-white" />
          </button>
        )}
      </div>
    </div>
  );
}
