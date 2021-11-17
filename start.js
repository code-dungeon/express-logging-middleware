const express = require('express');
const { ctx } = require('@code-dungeon/context-continuation');
const { Logger } = require('@code-dungeon/toothpick');
const { create } = require('./dist');

const app = express();
const port = 8080;
const defaultFormats = [
  Logger.Format.context(() => {
    return ctx.cid;
  }, 'cid'),
  Logger.Format.json(),
  Logger.Format.splat()
]

Logger.Config.formats = defaultFormats;


// const entryLogger = Logger.create({ format: [entryFormat, ...Logger.Config.formats] });
// const exitLogger = Logger.create({ format: [exitFormat, ...Logger.Config.formats] });

const logger = Logger.create();
logger.info('server:%s', 'start');
logger.info({ server: 'start' });

const middlewareLogger = Logger.create({
  formats: [
    Logger.Format.context(() => {
      const { status, duration, path, ttfb } = ctx.http;
      let response = ctx.http.responseBody;

      return { duration, path, response, status, ttfb };
    }),
    ...Logger.Config.formats
  ]
});

app.use(create(middlewareLogger));
// app.use(LoggingMiddleware(entryLogger, exitLogger));
app.get('/test', (request, response) => {
  if (request.query.arg) {
    response.status(400).json({ status: 'oops!' });
  } else {
    response.json({ status: 'ok' });
  }
});
app.listen(port);
