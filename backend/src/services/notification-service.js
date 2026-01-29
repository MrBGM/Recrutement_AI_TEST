/**
 * Service de notifications push (Firebase Cloud Messaging)
 * Envoie des notifications aux utilisateurs via FCM
 */

import admin from 'firebase-admin';
import logger from '../utils/logger.js';

export class NotificationService {
  constructor() {
    this.messaging = admin.messaging();
  }

  /**
   * Envoie une notification à un utilisateur spécifique
   * @param {Object} params - Paramètres de notification
   * @param {string} params.fcmToken - Token FCM du destinataire
   * @param {string} params.title - Titre de la notification
   * @param {string} params.body - Corps de la notification
   * @param {Object} params.data - Données additionnelles
   * @returns {Promise<string>} - ID du message envoyé
   */
  async sendNotification({ fcmToken, title, body, data = {} }) {
    try {
      const message = {
        token: fcmToken,
        notification: {
          title,
          body,
        },
        data: {
          ...data,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'ai_chat_messages',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      };

      const response = await this.messaging.send(message);
      logger.info('Notification envoyée avec succès', { messageId: response });
      return response;
    } catch (error) {
      logger.error('Erreur envoi notification', { error: error.message });
      throw error;
    }
  }

  /**
   * Envoie une notification de nouveau message
   * @param {Object} params - Paramètres
   * @param {string} params.recipientToken - Token FCM du destinataire
   * @param {string} params.senderName - Nom de l'expéditeur
   * @param {string} params.messageContent - Contenu du message
   * @param {string} params.conversationId - ID de la conversation
   */
  async sendNewMessageNotification({
    recipientToken,
    senderName,
    messageContent,
    conversationId,
  }) {
    const truncatedMessage =
      messageContent.length > 100
        ? `${messageContent.substring(0, 100)}...`
        : messageContent;

    return this.sendNotification({
      fcmToken: recipientToken,
      title: senderName,
      body: truncatedMessage,
      data: {
        type: 'new_message',
        conversationId,
      },
    });
  }

  /**
   * Envoie une notification de message lu
   * @param {Object} params - Paramètres
   * @param {string} params.recipientToken - Token FCM du destinataire
   * @param {string} params.readerName - Nom de celui qui a lu
   * @param {string} params.conversationId - ID de la conversation
   */
  async sendMessageReadNotification({
    recipientToken,
    readerName,
    conversationId,
  }) {
    return this.sendNotification({
      fcmToken: recipientToken,
      title: 'Message lu',
      body: `${readerName} a lu votre message`,
      data: {
        type: 'message_read',
        conversationId,
      },
    });
  }

  /**
   * Envoie des notifications en masse
   * @param {Array} tokens - Liste de tokens FCM
   * @param {Object} notification - Données de notification
   */
  async sendBulkNotifications(tokens, notification) {
    try {
      const message = {
        tokens,
        notification,
        android: {
          priority: 'high',
        },
      };

      const response = await this.messaging.sendEachForMulticast(message);
      logger.info('Notifications en masse envoyées', {
        successCount: response.successCount,
        failureCount: response.failureCount,
      });

      return response;
    } catch (error) {
      logger.error('Erreur envoi notifications en masse', { error: error.message });
      throw error;
    }
  }

  /**
   * Vérifie et nettoie les tokens invalides
   * @param {string} token - Token à vérifier
   */
  async validateToken(token) {
    try {
      await this.messaging.send({
        token,
        data: { type: 'test' },
      }, true); // dry run
      return true;
    } catch (error) {
      if (error.code === 'messaging/invalid-registration-token' ||
          error.code === 'messaging/registration-token-not-registered') {
        logger.warn('Token FCM invalide', { token });
        return false;
      }
      throw error;
    }
  }
}

// Export singleton
export const notificationService = new NotificationService();
export default notificationService;