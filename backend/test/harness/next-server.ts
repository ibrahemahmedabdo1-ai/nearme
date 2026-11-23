export class NextRequest extends Request {}
export const NextResponse = { json: (data: unknown, init?: ResponseInit) => Response.json(data, init) };
