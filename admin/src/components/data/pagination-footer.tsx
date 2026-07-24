"use client";

import type { ReactNode } from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";

import styles from "./pagination-footer.module.css";

interface PaginationFooterProps {
  page: number;
  pageSize: number;
  pageSizes: number[];
  totalCount: number;
  onPageChange: (page: number) => void;
  onPageSizeChange: (pageSize: number) => void;
  itemLabel?: string;
  children?: ReactNode;
}

export function PaginationFooter({
  page,
  pageSize,
  pageSizes,
  totalCount,
  onPageChange,
  onPageSizeChange,
  itemLabel = "rows",
  children,
}: PaginationFooterProps) {
  const totalPages = Math.max(1, Math.ceil(totalCount / pageSize));

  return (
    <footer className={styles.pagination}>
      <label>
        Rows per page
        <select
          onChange={(event) => {
            onPageSizeChange(Number(event.target.value));
          }}
          value={pageSize}
        >
          {pageSizes.map((size) => (
            <option key={size} value={size}>
              {size}
            </option>
          ))}
        </select>
      </label>
      <span>
        {totalCount
          ? `${page * pageSize + 1}–${Math.min((page + 1) * pageSize, totalCount)} of ${totalCount.toLocaleString()}`
          : `0 ${itemLabel}`}
      </span>
      <div>
        <button
          aria-label="Previous page"
          disabled={page <= 0}
          onClick={() => onPageChange(page - 1)}
          type="button"
        >
          <ChevronLeft size={17} />
        </button>
        <span>
          Page {page + 1} of {totalPages}
        </span>
        <button
          aria-label="Next page"
          disabled={page + 1 >= totalPages}
          onClick={() => onPageChange(page + 1)}
          type="button"
        >
          <ChevronRight size={17} />
        </button>
      </div>
      {children}
    </footer>
  );
}
