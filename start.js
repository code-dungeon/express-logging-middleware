const express = require('express');
const { ctx } = require('@code-dungeon/context-continuation');
const { Logger } = require('@code-dungeon/toothpick');
const { create } = require('./dist');
const bodyParser = require('body-parser');
const compress = require('compression');
const cors = require('cors');
const hooks = require('async_hooks');

const app = express();

app.use(bodyParser.json({
  limit: '10mb'
}));

app.use(bodyParser.urlencoded({
  extended: false,
  limit: '15mb'
}));

app.use(compress());

app.use(cors({
  credentials: true,
  origin: true
}));

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

function dostuff(cb) {

  console.log('before nextTick', hooks.executionAsyncId())
  process.nextTick(function () {
    console.log('after nextTick', hooks.executionAsyncId())
    console.log(ctx);
    cb.apply(null);
  });
}

app.get('/test', (request, response) => {
  if (request.query.arg) {
    response.status(400).json({ status: 'oops!' });
  } else {
    // response.json({ status: 'ok' });
    dostuff(function () {
      response.send('ok');
    })
  }
});
app.listen(port);
