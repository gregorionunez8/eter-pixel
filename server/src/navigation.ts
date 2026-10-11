import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { adaptMaps } from "./content.js";
export type Point = { x: number; y: number };
export const geometry = JSON.parse(
  readFileSync(resolve("../shared/world.json"), "utf8"),
);
export const mapsCatalog = adaptMaps(JSON.parse(
  readFileSync(resolve("../shared/maps.json"), "utf8"),
));
const distance = (a: Point, b: Point) => Math.hypot(a.x - b.x, a.y - b.y);
export class Navigation {
  private blocked = new Set<number>();
  constructor(readonly data: any = geometry) {
    for (const rect of this.data.obstacles)
      for (let y = rect.y; y < rect.y + rect.height; y++)
        for (let x = rect.x; x < rect.x + rect.width; x++)
          this.blocked.add(this.id({ x, y }));
  }
  private id(cell: Point) {
    return cell.y * this.data.width + cell.x;
  }
  private cell(id: number): Point {
    return { x: id % this.data.width, y: Math.floor(id / this.data.width) };
  }
  cellAt(point: Point): Point {
    return {
      x: Math.floor(point.x / this.data.tile),
      y: Math.floor(point.y / this.data.tile),
    };
  }
  center(cell: Point): Point {
    return {
      x: (cell.x + 0.5) * this.data.tile,
      y: (cell.y + 0.5) * this.data.tile,
    };
  }
  walkable(cell: Point) {
    return (
      cell.x >= 0 &&
      cell.y >= 0 &&
      cell.x < this.data.width &&
      cell.y < this.data.height &&
      !this.blocked.has(this.id(cell))
    );
  }
  bounded(point: Point) {
    return (
      Number.isFinite(point.x) &&
      Number.isFinite(point.y) &&
      point.x >= 0 &&
      point.y >= 0 &&
      point.x < this.data.width * this.data.tile &&
      point.y < this.data.height * this.data.tile
    );
  }
  safe(point: Point, radius = 7) {
    if (!this.bounded(point) || !this.walkable(this.cellAt(point)))
      return false;
    for (const rect of this.data.obstacles) {
      const left = rect.x * this.data.tile,
        top = rect.y * this.data.tile,
        right = (rect.x + rect.width) * this.data.tile,
        bottom = (rect.y + rect.height) * this.data.tile;
      const closest = {
        x: Math.max(left, Math.min(right, point.x)),
        y: Math.max(top, Math.min(bottom, point.y)),
      };
      if (distance(point, closest) < radius) return false;
    }
    return true;
  }
  private route(start: Point, finish: Point): Point[] {
    if (!this.walkable(start) || !this.walkable(finish)) return [];
    const startId = this.id(start),
      finishId = this.id(finish),
      open = [startId],
      closed = new Set<number>();
    const cost = new Map([[startId, 0]]),
      previous = new Map<number, number>();
    const heuristic = (cell: Point) => {
      const dx = Math.abs(cell.x - finish.x),
        dy = Math.abs(cell.y - finish.y);
      return Math.max(dx, dy) + (Math.SQRT2 - 1) * Math.min(dx, dy);
    };
    const score = (id: number) => cost.get(id)! + heuristic(this.cell(id));
    while (open.length) {
      open.sort((a, b) => score(b) - score(a));
      const current = open.pop()!;
      if (current === finishId) {
        const path = [current];
        while (previous.has(path[0])) path.unshift(previous.get(path[0])!);
        return path.map((id) => this.center(this.cell(id)));
      }
      closed.add(current);
      const cell = this.cell(current);
      for (let dy = -1; dy <= 1; dy++)
        for (let dx = -1; dx <= 1; dx++) {
          if (!dx && !dy) continue;
          const next = { x: cell.x + dx, y: cell.y + dy },
            id = this.id(next);
          if (
            !this.walkable(next) ||
            closed.has(id) ||
            (dx &&
              dy &&
              (!this.walkable({ x: cell.x + dx, y: cell.y }) ||
                !this.walkable({ x: cell.x, y: cell.y + dy })))
          )
            continue;
          const candidate = cost.get(current)! + (dx && dy ? Math.SQRT2 : 1);
          if (candidate < (cost.get(id) ?? Infinity)) {
            cost.set(id, candidate);
            previous.set(id, current);
            if (!open.includes(id)) open.push(id);
          }
        }
    }
    return [];
  }
  findPath(from: Point, to: Point): Point[] {
    if (!this.safe(from) || !this.bounded(to)) return [];
    const start = this.cellAt(from),
      finish = this.cellAt(to);
    let result: Point[] = [];
    if (this.walkable(finish)) result = this.route(start, finish);
    else
      for (let radius = 1; radius <= 8; radius++) {
        let best = Infinity;
        for (let y = finish.y - radius; y <= finish.y + radius; y++)
          for (let x = finish.x - radius; x <= finish.x + radius; x++) {
            const candidate = { x, y },
              squared = (x - finish.x) ** 2 + (y - finish.y) ** 2;
            if (squared >= best || !this.walkable(candidate)) continue;
            const route = this.route(start, candidate);
            if (route.length) {
              result = route;
              best = squared;
            }
          }
        if (result.length) break;
      }
    if (result.length && distance(result[0], from) < 1) result.shift();
    return result;
  }
}
