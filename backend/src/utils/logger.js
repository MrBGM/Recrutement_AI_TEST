/**
 * Systeme de logging centralise
 * Utilise Winston pour une gestion avancee des logs
 */

import winston from 'winston';
import config from '../config/index.js';

const { combine, timestamp, printf, colorize, errors } = winston.format;

// Format personnalise pour les logs
const logFormat = printf(({ level, message, timestamp, stack, ...metadata }) => {
  let log = `${timestamp} [${level}]: ${message}`;

  // Ajouter les metadonnees si presentes
  if (Object.keys(metadata).length > 0) {
    log += ` ${JSON.stringify(metadata)}`;
  }

  // Ajouter la stack trace en cas d'erreur
  if (stack) {
    log += `\n${stack}`;
  }

  return log;
});

// Configuration du logger
const logger = winston.createLogger({
  level: config.isProduction ? 'info' : 'debug',
  format: combine(
    errors({ stack: true }),
    timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    logFormat
  ),
  defaultMeta: { service: 'ai-chat-backend' },
  transports: [
    // Console avec couleurs en dev
    new winston.transports.Console({
      format: combine(
        colorize({ all: !config.isProduction }),
        logFormat
      ),
    }),
  ],
});

// Ajouter un transport fichier en production
if (config.isProduction) {
  logger.add(
    new winston.transports.File({
      filename: 'logs/error.log',
      level: 'error',
    })
  );
  logger.add(
    new winston.transports.File({
      filename: 'logs/combined.log',
    })
  );
}

export default logger;
