// Lightweight schema migration + demo seed for initial deployments.
import { randomUUID } from 'node:crypto';

import { db } from './knex';
import { env } from '../config/env';

const demoPasswordHash = '$2b$10$d3YKIANfDm9d/h4DFyx9yOd/SNSIiz0taN1QPwemok06k81STfMOC';

// Tenant table to separate broker organizations.
async function createTenantsTable(): Promise<void> {
  const exists = await db.schema.hasTable('tenants');
  if (exists) {
    return;
  }

  await db.schema.createTable('tenants', (table) => {
    table.string('id', 36).primary();
    table.string('name', 120).notNullable();
    table.string('deployment_mode', 20).notNullable().defaultTo('saas');
    table.timestamp('created_at').notNullable().defaultTo(db.fn.now());
  });
}

// Minimal user table for demo roles.
async function createUsersTable(): Promise<void> {
  const exists = await db.schema.hasTable('users');
  if (exists) {
    return;
  }

  await db.schema.createTable('users', (table) => {
    table.string('id', 36).primary();
    table.string('tenant_id', 36).notNullable().index();
    table.string('role', 20).notNullable().index();
    table.string('name', 80).notNullable();
    table.string('email', 160).notNullable().index();
    table.string('password_hash', 120).nullable();
    table.string('external_provider', 64).nullable();
    table.string('external_subject', 128).nullable();
    table.timestamp('created_at').notNullable().defaultTo(db.fn.now());
  });
}

// Ensure auth-related columns exist on existing databases.
async function ensureUserColumns(): Promise<void> {
  const exists = await db.schema.hasTable('users');
  if (!exists) {
    return;
  }

  const hasPasswordHash = await db.schema.hasColumn('users', 'password_hash');
  if (!hasPasswordHash) {
    await db.schema.alterTable('users', (table) => {
      table.string('password_hash', 120).nullable();
    });
  }

  const hasExternalProvider = await db.schema.hasColumn('users', 'external_provider');
  if (!hasExternalProvider) {
    await db.schema.alterTable('users', (table) => {
      table.string('external_provider', 64).nullable();
    });
  }

  const hasExternalSubject = await db.schema.hasColumn('users', 'external_subject');
  if (!hasExternalSubject) {
    await db.schema.alterTable('users', (table) => {
      table.string('external_subject', 128).nullable();
    });
  }
}

// Family table representing household groups.
async function createFamiliesTable(): Promise<void> {
  const exists = await db.schema.hasTable('families');
  if (exists) {
    return;
  }

  await db.schema.createTable('families', (table) => {
    table.string('id', 36).primary();
    table.string('tenant_id', 36).notNullable().index();
    table.string('name', 120).notNullable();
    table.string('owner_user_id', 36).notNullable().index();
    table.timestamp('created_at').notNullable().defaultTo(db.fn.now());
  });
}

// Core policy table for AI insights and coverage metadata.
async function createPoliciesTable(): Promise<void> {
  const exists = await db.schema.hasTable('policies');
  if (exists) {
    return;
  }

  await db.schema.createTable('policies', (table) => {
    table.string('id', 36).primary();
    table.string('tenant_id', 36).notNullable().index();
    table.string('family_id', 36).notNullable().index();
    table.string('policy_no', 120).notNullable().index();
    table.string('insurer_name', 120).notNullable();
    table.string('product_name', 160).notNullable();
    table.decimal('premium', 14, 2).notNullable().defaultTo(0);
    table.string('currency', 8).notNullable().defaultTo('CNY');
    table.string('status', 32).notNullable().defaultTo('active').index();
    table.date('start_date').notNullable();
    table.date('end_date').nullable();
    table.decimal('ai_risk_score', 5, 2).nullable();
    table.text('ai_notes').nullable();
    table.string('created_by_user_id', 36).notNullable().index();
    table.timestamp('created_at').notNullable().defaultTo(db.fn.now());
    table.timestamp('updated_at').notNullable().defaultTo(db.fn.now());
  });
}

// Family member table for household profiles.
async function createFamilyMembersTable(): Promise<void> {
  const exists = await db.schema.hasTable('family_members');
  if (exists) {
    return;
  }

  await db.schema.createTable('family_members', (table) => {
    table.string('id', 36).primary();
    table.string('tenant_id', 36).notNullable().index();
    table.string('family_id', 36).notNullable().index();
    table.string('name', 120).notNullable();
    table.string('relation', 80).notNullable();
    table.string('gender', 20).nullable();
    table.date('birth_date').nullable();
    table.string('phone', 40).nullable();
    table.timestamp('created_at').notNullable().defaultTo(db.fn.now());
  });
}

// Policy document table for uploaded PDF forms.
async function createPolicyDocumentsTable(): Promise<void> {
  const exists = await db.schema.hasTable('policy_documents');
  if (exists) {
    return;
  }

  await db.schema.createTable('policy_documents', (table) => {
    table.string('id', 36).primary();
    table.string('tenant_id', 36).notNullable().index();
    table.string('family_id', 36).notNullable().index();
    table.string('policy_id', 36).nullable().index();
    table.string('file_name', 180).notNullable();
    table.string('storage_path', 240).notNullable();
    table.string('mime_type', 80).notNullable();
    table.bigInteger('file_size').notNullable().defaultTo(0);
    table.string('doc_type', 40).notNullable().defaultTo('policy-form');
    table.string('uploaded_by_user_id', 36).notNullable().index();
    table.timestamp('created_at').notNullable().defaultTo(db.fn.now());
  });
}

// Insert deterministic demo records if they are missing.
async function insertIfMissing(table: string, id: string, payload: Record<string, unknown>): Promise<void> {
  const found = await db(table).where('id', id).first();
  if (!found) {
    await db(table).insert(payload);
  }
}

// Seed a minimal broker + consumer + family + policy set.
async function seedDemoData(): Promise<void> {
  const tenantId = env.defaultTenantId;
  const brokerId = 'user-broker-demo';
  const consumerId = 'user-consumer-demo';
  const familyId = 'family-demo';
  const now = new Date().toISOString();

  await insertIfMissing('tenants', tenantId, {
    id: tenantId,
    name: env.tenantMode === 'private' ? 'Private Broker Tenant' : 'SaaS Demo Tenant',
    deployment_mode: env.tenantMode,
  });

  await insertIfMissing('users', brokerId, {
    id: brokerId,
    tenant_id: tenantId,
    role: 'broker',
    name: 'Demo Broker',
    email: 'broker@example.com',
    password_hash: demoPasswordHash,
  });

  await insertIfMissing('users', consumerId, {
    id: consumerId,
    tenant_id: tenantId,
    role: 'consumer',
    name: 'Demo Consumer',
    email: 'consumer@example.com',
    password_hash: demoPasswordHash,
  });

  await insertIfMissing('families', familyId, {
    id: familyId,
    tenant_id: tenantId,
    name: 'Demo Family',
    owner_user_id: consumerId,
  });

  const existingPolicies = await db('policies').where('tenant_id', tenantId).count<{ count: number }[]>('* as count');
  const total = Number(existingPolicies[0]?.count ?? 0);

  if (total > 0) {
    return;
  }

  await db('policies').insert([
    {
      id: randomUUID(),
      tenant_id: tenantId,
      family_id: familyId,
      policy_no: 'PA-2026-0001',
      insurer_name: 'Ping An',
      product_name: 'Family Accident Protection',
      premium: 1560,
      currency: 'CNY',
      status: 'active',
      start_date: '2026-01-01',
      end_date: '2026-12-31',
      ai_risk_score: 14.5,
      ai_notes: 'Coverage is strong; consider critical illness add-ons.',
      created_by_user_id: brokerId,
      created_at: now,
      updated_at: now,
    },
    {
      id: randomUUID(),
      tenant_id: tenantId,
      family_id: familyId,
      policy_no: 'CPIC-2026-0009',
      insurer_name: 'CPIC',
      product_name: 'Critical Illness Plan',
      premium: 4890,
      currency: 'CNY',
      status: 'active',
      start_date: '2026-02-01',
      end_date: '2027-01-31',
      ai_risk_score: 36.2,
      ai_notes: 'Premium ratio is acceptable; watch waiting period terms.',
      created_by_user_id: consumerId,
      created_at: now,
      updated_at: now,
    },
  ]);

  const existingMembers = await db('family_members')
    .where('tenant_id', tenantId)
    .count<{ count: number }[]>('* as count');
  const memberTotal = Number(existingMembers[0]?.count ?? 0);
  if (memberTotal === 0) {
    await db('family_members').insert([
      {
        id: randomUUID(),
        tenant_id: tenantId,
        family_id: familyId,
        name: 'Alex Zhang',
        relation: 'Self',
        gender: 'male',
        birth_date: '1992-06-01',
        phone: '18800001111',
        created_at: now,
      },
      {
        id: randomUUID(),
        tenant_id: tenantId,
        family_id: familyId,
        name: 'Lina Zhang',
        relation: 'Spouse',
        gender: 'female',
        birth_date: '1994-03-12',
        phone: '18800002222',
        created_at: now,
      },
    ]);
  }
}

// Run all schema steps in sequence.
export async function runMigrations(): Promise<void> {
  await createTenantsTable();
  await createUsersTable();
  await ensureUserColumns();
  await createFamiliesTable();
  await createPoliciesTable();
  await createFamilyMembersTable();
  await createPolicyDocumentsTable();
  await seedDemoData();
}

// Allow running migrations directly via node/tsx.
if (require.main === module) {
  runMigrations()
    .then(async () => {
      await db.destroy();
      // eslint-disable-next-line no-console
      console.log('Database migration completed.');
      process.exit(0);
    })
    .catch(async (error) => {
      // eslint-disable-next-line no-console
      console.error('Database migration failed:', error);
      await db.destroy();
      process.exit(1);
    });
}
