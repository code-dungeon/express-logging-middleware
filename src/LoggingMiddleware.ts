import { Logger } from '@code-dungeon/toothpick';
import { ctx } from '@code-dungeon/context-continuation';
import { Request, Response, NextFunction, RequestHandler } from 'express';

const { v4 } = require('uuid');
const now: Function = require('performance-now');

interface HttpProperties {
  path: string;
  request: Request;
  response: Response;
  requestBody?: string;
  responseBody?: string;
  status?: number;
  duration?: number;
  ttfb?: number;
}

function getPath(req: Request): string {
  let path: string = req.originalUrl;

  if (req.route !== undefined) {
    path = req.route.path;
  }

  return path;
}

function getHttpProperties(request: Request, response: Response): HttpProperties {
  const path: string = getPath(request);
  const { body: requestBody } = request;
  return { path, request, response, requestBody };
}

function addContextProperties(request: Request, response: Response): void {
  ctx.http = getHttpProperties(request, response);
  ctx.cid = request.get('correlation-id') || v4();
}

class MiddlewareZone {
  private response: Response;
  private entryLogger: Logger.Interface;
  private exitLogger: Logger.Interface;
  private start: number = now();
  private exitHandled: boolean = false;
  private chunks: Array<any>;
  private timeToFirstByte: number;

  constructor(entryLogger: Logger.Interface, exitLogger: Logger.Interface, request: Request, response: Response) {
    this.response = response;
    this.chunks = [];
    this.entryLogger = entryLogger;
    this.exitLogger = entryLogger;
    this.patchResponse(response);

    if (exitLogger) {
      this.exitLogger = exitLogger;
    }

    this.logEnter();
  }

  protected patchResponse(response: Response): void {
    const write: Function = response.write;
    const end: Function = response.end;
    /* istanbul ignore else */
    if (Boolean(write)) {
      response.write = (...args: Array<any>): boolean => {
        this.addChunks(args);
        const result: boolean = write.apply(response, args);
        this.setTimeToFirstByte();
        return result;
      };
    }

    response.end = (...args: Array<any>): Response => {
      this.addChunks(args);
      end.apply(response, args);
      this.setTimeToFirstByte();
      this.logExit();
      return response;
    };
  }

  private setTimeToFirstByte(): void {
    if (this.timeToFirstByte === undefined) {
      this.timeToFirstByte = Math.round(now() - this.start);
    }
  }

  private addChunks(args: Array<any>): void {
    const chunk: any = args[0];
    if (Boolean(chunk) === false) {
      return;
    }

    this.chunks.push(chunk);
  }

  protected logEnter(): void {
    this.entryLogger.info({ state: 'enter' });
  }

  protected logExit(): void {
    if (this.exitHandled === true) {
      return;
    }

    this.exitHandled = true;
    const end: number = now();

    const duration: number = Math.round(end - this.start);
    const { http = {} } = ctx;
    const { statusCode } = this.response;

    http.status = statusCode;
    http.duration = duration;
    http.ttfb = this.timeToFirstByte;

    ctx.http = http;

    if (this.chunks.length > 0 && Buffer.isBuffer(this.chunks[0])) {
      http.responseBody = Buffer.concat(this.chunks).toString('utf8');
    }

    if (statusCode < 400) {
      this.exitLogger.info({ state: 'exit' });
    } else {

      this.exitLogger.error({ state: 'exit' });
    }
  }
}

/**
 * Returns a function that will log express requests and their responses
 * This uses two loggers, allowing district formats for entry vs exist.
 * If only one logger is provided, it will use the same logger for entry
 * and exit messages.
 * @param logger The logger used when a route is entered and optional exited
 * @parem exitLogger If provided the completion of a route will only use this logger
 * @returns {RequestHandler}
 */
export function createMiddleware(logger: Logger.Interface, exitLogger?: Logger.Interface): RequestHandler {
  // The async id for the handler is always the same, to force a new flow
  // so the request context is separate the work is done in process.nextTick
  return function loggingMiddleware(request: Request, response: Response, next: NextFunction): void {
    process.nextTick(ctx.$init(() => {
      addContextProperties(request, response);
      const spec: MiddlewareZone = new MiddlewareZone(logger, exitLogger, request, response);
      next();
    }));
  };
}
