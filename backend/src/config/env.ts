import 'dotenv/config';

const num = (v: string | undefined, d: number) => (v ? Number(v) : d);
const bool = (v: string | undefined, d = false) => (v === undefined ? d : v === 'true');

export const env = {
  nodeEnv: process.env.NODE_ENV ?? 'development',
  isProd: process.env.NODE_ENV === 'production',
  isTest: process.env.NODE_ENV === 'test',
  port: num(process.env.PORT, 8080),
  apiPrefix: process.env.API_PREFIX ?? '/api/v1',
  corsOrigins: (process.env.CORS_ORIGINS ?? '*').split(',').map((s) => s.trim()),
  databaseUrl: process.env.DATABASE_URL ?? '',
  jwtSecret: process.env.JWT_SECRET ?? 'dev-secret',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? '7d',
  adminBootstrapEmail: process.env.ADMIN_BOOTSTRAP_EMAIL ?? 'admin@gamya.com',
  adminBootstrapPassword: process.env.ADMIN_BOOTSTRAP_PASSWORD ?? 'Admin@123',
  storageDriver: (process.env.STORAGE_DRIVER ?? 'local') as 'local' | 'gcs',
  localUploadDir: process.env.LOCAL_UPLOAD_DIR ?? 'uploads',
  gcsBucket: process.env.GCS_BUCKET ?? '',
  gcsProjectId: process.env.GCS_PROJECT_ID ?? '',
  faceVerifyDriver: (process.env.FACE_VERIFY_DRIVER ?? 'mock') as 'mock' | 'vision',
  faceMatchThreshold: num(process.env.FACE_MATCH_THRESHOLD, 0.75),
  fcmEnabled: bool(process.env.FCM_ENABLED, false),
  firebaseServiceAccountJson: process.env.FIREBASE_SERVICE_ACCOUNT_JSON,
  publicBaseUrl: process.env.PUBLIC_BASE_URL ?? '',
};
