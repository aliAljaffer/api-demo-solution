FROM node@sha256:626f797909b3c888a7633ddbff03d9aa3be8424a7ffaf48feb4ac4a138e56e55

ARG ENV=dev

RUN echo "this is a test PR"

ENV NODE_ENV=${ENV}
ENV PORT=8080

WORKDIR /app

COPY package*.json ./

RUN if [ "$ENV" = "prod" ] || [ "$ENV" = "production" ]; then \
        OMIT="--omit=dev"; \
    else \
        OMIT=""; \
    fi && \
    if [ -f package-lock.json ]; then \
        npm ci $OMIT; \
    else \
        npm install $OMIT; \
    fi

COPY . .

EXPOSE 8080

HEALTHCHECK --interval=30s \
    --timeout=5s \
    --start-period=10s \
    --retries=3 \
    CMD node -e "fetch('http://127.0.0.1:' + (process.env.PORT || 8080) + '/health').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"

CMD ["npm", "run", "start"]
