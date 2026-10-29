FROM nginx:alpine

COPY website/ /usr/share/nginx/html/
EXPOSE 80

HEALTHCHECK --interval=15s --timeout=3s --retries=3 CMD wget -q -O /dev/null http://127.0.0.1/ || exit 1
CMD ["nginx", "-g", "daemon off;"]
