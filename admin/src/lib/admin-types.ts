export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export type SortDirection = "asc" | "desc";

export interface AdminProfile {
  id: string;
  email: string;
  full_name: string;
  role: "student" | "cr" | "super_admin";
  status: "active" | "suspended" | "archived" | "deleted";
  batch_id: string | null;
  department_id: string | null;
  avatar_url: string | null;
  deleted_at: string | null;
}

export interface ForeignKeyMetadata {
  table: string;
  column: string;
}

export interface ColumnMetadata {
  name: string;
  data_type: string;
  base_type: string;
  nullable: boolean;
  default: string | null;
  primary_key: boolean;
  identity: boolean;
  generated: boolean;
  enum_values: string[] | null;
  foreign_key: ForeignKeyMetadata | null;
  comment: string | null;
}

export interface TableMetadata {
  name: string;
  kind: "table" | "partitioned_table" | "view" | "materialized_view";
  comment: string | null;
  estimated_rows: number;
  total_bytes: number;
  columns: ColumnMetadata[];
}

export interface SchemaCatalogResponse {
  generated_at: string;
  relations: TableMetadata[];
}

export type EntityGroupId =
  | "accounts"
  | "academic"
  | "attendance"
  | "content"
  | "workflows"
  | "campus"
  | "club"
  | "system";

export interface EntityCapabilities {
  create: boolean;
  update: boolean;
  delete: boolean;
}

export interface EntityDefinition {
  name: string;
  label: string;
  singular: string;
  group: EntityGroupId;
  description: string;
  searchColumns: string[];
  preferredColumns: string[];
  defaultSort: string;
  defaultDirection?: SortDirection;
  softDelete?: boolean;
  readOnly?: boolean;
  managedRoute?: string;
  capabilities?: Partial<EntityCapabilities>;
  lockedColumns?: string[];
  updateLockedColumns?: string[];
}

export type RowData = Record<string, unknown>;

export interface PagedRows {
  rows: RowData[];
  count: number;
}
