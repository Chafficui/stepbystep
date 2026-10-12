# Das API-Image: Server plus Orga-Dashboard.
#
# WARUM IM WURZELVERZEICHNIS UND NICHT IN server/. Das Dashboard liegt in
# dashboard/, und ein Build-Kontext von server/ kann nicht darauf zugreifen.
# Die Produktions-Compose loeste das mit einem Host-Mount
# (`../dashboard:/app/dashboard:ro`) — das funktioniert dort, wo das
# Repository neben dem Container liegt, und nirgends sonst. Auf codai up gibt
# es nur benannte Volumes und kein Repository auf dem Host, also waere
# DASHBOARD_DIR leer geblieben und `/` haette 404 geantwortet, waehrend API und
# Healthcheck einwandfrei aussehen.
#
# Jetzt liegt das Dashboard IM Image. Damit gibt es eine Bildbeschreibung fuer
# beide Wege (Compose und up), und das Dashboard ist Teil dessen, was gebaut
# und versioniert wird, statt eines Verzeichnisses, das zufaellig daneben liegt.

FROM node:22-alpine AS build
WORKDIR /app
COPY server/package.json server/package-lock.json ./
RUN npm ci
COPY server/tsconfig.json ./
COPY server/src ./src
RUN npx tsc

FROM node:22-alpine
ENV NODE_ENV=production
WORKDIR /app
COPY server/package.json server/package-lock.json ./
RUN npm ci --omit=dev
COPY server/migrations ./migrations
COPY --from=build /app/dist ./dist
# Das Dashboard, eine einzelne HTML-Datei. DASHBOARD_DIR zeigt darauf; der
# Server prueft mit existsSync und liefert es unter / aus.
COPY dashboard ./dashboard
ENV DASHBOARD_DIR=/app/dashboard
EXPOSE 8080
CMD ["node", "dist/index.js"]
