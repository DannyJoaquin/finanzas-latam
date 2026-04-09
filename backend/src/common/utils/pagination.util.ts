export interface PaginationParams {
  page?: number;
  limit?: number;
}

export interface PaginationMeta {
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

export function parsePagination(params: PaginationParams): { skip: number; take: number; page: number; limit: number } {
  const page = Math.max(1, params.page ?? 1);
  const limit = Math.min(500, Math.max(1, params.limit ?? 20));
  return { skip: (page - 1) * limit, take: limit, page, limit };
}

export function buildMeta(total: number, page: number, limit: number): PaginationMeta {
  return {
    total,
    page,
    limit,
    totalPages: Math.ceil(total / limit),
  };
}
