"use client";

import { Search, X } from "lucide-react";

import styles from "./search-box.module.css";

interface SearchBoxProps {
  value: string;
  onChange: (value: string) => void;
  placeholder: string;
  ariaLabel?: string;
  disabled?: boolean;
}

export function SearchBox({ value, onChange, placeholder, ariaLabel, disabled }: SearchBoxProps) {
  return (
    <label className={styles.searchBox}>
      <Search size={17} />
      <input
        aria-label={ariaLabel}
        disabled={disabled}
        onChange={(event) => onChange(event.target.value)}
        placeholder={placeholder}
        value={value}
      />
      {value ? (
        <button aria-label="Clear search" onClick={() => onChange("")} type="button">
          <X size={15} />
        </button>
      ) : null}
    </label>
  );
}
