FROM dart:3.12.2 AS build

ARG SOURCE_COMMIT=unknown
WORKDIR /workspace

COPY packages/cohort_plan_package/pubspec.yaml \
     packages/cohort_plan_package/pubspec.lock \
     packages/cohort_plan_package/
COPY server/trusted_plan_package_import/pubspec.yaml \
     server/trusted_plan_package_import/pubspec.lock \
     server/trusted_plan_package_import/

WORKDIR /workspace/server/trusted_plan_package_import
RUN dart pub get --enforce-lockfile

WORKDIR /workspace
COPY packages/cohort_plan_package/lib packages/cohort_plan_package/lib
COPY server/trusted_plan_package_import/lib \
     server/trusted_plan_package_import/lib
COPY server/trusted_plan_package_import/bin \
     server/trusted_plan_package_import/bin

WORKDIR /workspace/server/trusted_plan_package_import
RUN mkdir -p /out \
    && dart compile exe bin/server.dart -o /out/trusted-plan-import

FROM gcr.io/distroless/base-debian12:nonroot

ARG SOURCE_COMMIT=unknown
LABEL org.opencontainers.image.source="cohort-platform" \
      org.opencontainers.image.revision="${SOURCE_COMMIT}" \
      org.opencontainers.image.title="Cohort trusted Plan Package import"

WORKDIR /app
COPY --from=build --chown=65532:65532 \
     /out/trusted-plan-import /app/trusted-plan-import

USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/app/trusted-plan-import"]
