# ==========================================
# Stage 1: Build (Compilation & Dépendances)
# ==========================================
FROM node:20-alpine AS builder

WORKDIR /build

# Optimisation du cache : on ne copie d'abord que les fichiers de configuration de paquets
COPY package*.json ./

# SecOps: Utilisation de npm ci pour une installation déterministe (verrouillage exact des versions)
# --ignore-scripts empêche l'exécution automatique de scripts postinstall potentiellement malveillants
RUN npm ci --ignore-scripts

# Copie du code source
COPY . .

# SecOps: On supprime les dépendances de développement (DevDependencies) 
# pour réduire la surface d'attaque sur l'image de production
RUN npm prune --production

# ==========================================
# Stage 2: Production (Image finale allégée)
# ==========================================
FROM node:20-alpine

# Hardening: Définir l'environnement de production désactive certains logs de debug verbeux
ENV NODE_ENV=production

WORKDIR /app

# SecOps: Changement de propriétaire lors de la copie pour éviter les problèmes de permissions
# On copie uniquement les node_modules allégés et le code compilé/source
COPY --from=builder --chown=node:node /build/node_modules ./node_modules
COPY --from=builder --chown=node:node /build/src ./src
COPY --from=builder --chown=node:node /build/package*.json ./

# Hardening: L'image node alpine fournit nativement l'utilisateur "node" (UID 1000)
# Ne **jamais** exécuter d'application en 'root' (PID 1 attack surface)
USER node

# L'API Node écoutera sur ce port
EXPOSE 8000

# Lancement de l'API Node directement ou via npm (mais 'node' direct expose mieux les signaux SIGTERM/SIGINT)
CMD ["node", "src/main.js"]
