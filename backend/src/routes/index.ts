import { Router } from 'express';
import { authenticate } from '../middleware/auth.js';
import { authRouter } from './auth.js';
import { dashboardRouter } from './dashboard.js';
import { supervisorsRouter } from './supervisors.js';
import { driversRouter } from './drivers.js';
import { vehiclesRouter } from './vehicles.js';
import { approvalsRouter } from './approvals.js';
import { adhocRouter } from './adhoc.js';
import { bookingsRouter } from './bookings.js';
import { tripsRouter } from './trips.js';
import { paymentsRouter } from './payments.js';
import { reportsRouter } from './reports.js';
import { notificationsRouter } from './notifications.js';
import { activityRouter, adminUsersRouter, clientsRouter, locationsRouter, platformsRouter, settingsRouter } from './masters.js';
import { driverMeRouter, supervisorMeRouter } from './me.js';

export const apiRouter = Router();

apiRouter.use('/auth', authRouter);
apiRouter.get('/platforms', platformsRouter); // public list (used by mobile before login)
apiRouter.get('/settings/public', settingsRouter);

apiRouter.use(authenticate);
apiRouter.use('/dashboard', dashboardRouter);
apiRouter.use('/supervisors', supervisorsRouter);
apiRouter.use('/drivers', driversRouter);
apiRouter.use('/vehicles', vehiclesRouter);
apiRouter.use('/approvals', approvalsRouter);
apiRouter.use('/adhoc', adhocRouter);
apiRouter.use('/bookings', bookingsRouter);
apiRouter.use('/trips', tripsRouter);
apiRouter.use('/payments', paymentsRouter);
apiRouter.use('/reports', reportsRouter);
apiRouter.use('/notifications', notificationsRouter);
apiRouter.use('/platforms', platformsRouter);
apiRouter.use('/clients', clientsRouter);
apiRouter.use('/locations', locationsRouter);
apiRouter.use('/settings', settingsRouter);
apiRouter.use('/admin-users', adminUsersRouter);
apiRouter.use('/activity', activityRouter);
apiRouter.use('/driver', driverMeRouter);
apiRouter.use('/supervisor', supervisorMeRouter);
