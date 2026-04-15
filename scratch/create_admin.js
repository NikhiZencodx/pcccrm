const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://oqxmpiuqovzfiufjzmdu.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9xeG1waXVxb3Z6Zml1Zmp6bWR1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjI0MDE1OSwiZXhwIjoyMDkxODE2MTU5fQ.-tY0nbB9Qo6lEGaRkrJum3LeHNkeNhAnTRhkopyOthY';

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function createAdmin() {
  const email = 'admin@peacecareer.com';
  const password = 'PeaceAdmin@2026';

  console.log(`Creating user: ${email}...`);

  // 1. Create user in Auth
  const { data: authData, error: authError } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true
  });

  if (authError) {
    if (authError.message.includes('already registered')) {
      console.log('User already exists in Auth.');
    } else {
      console.error('Error creating auth user:', authError.message);
      return;
    }
  }

  const userId = authData?.user?.id;
  
  if (!userId) {
    // If user exists, we might need to fetch the ID to ensure profile exists
    const { data: listUsers } = await supabase.auth.admin.listUsers();
    const existingUser = listUsers.users.find(u => u.email === email);
    if (existingUser) {
        console.log('Found existing user ID:', existingUser.id);
        await createProfile(existingUser.id, email);
    }
    return;
  }

  await createProfile(userId, email);
}

async function createProfile(id, email) {
  console.log(`Creating profile for ${email}...`);
  const { error: profileError } = await supabase
    .from('profiles')
    .upsert({
      id,
      email,
      full_name: 'Super Admin',
      role: 'admin',
      is_active: true
    });

  if (profileError) {
    console.error('Error creating profile (did you run migrations?):', profileError.message);
  } else {
    console.log('✅ Admin user created successfully!');
    console.log('-----------------------------------');
    console.log(`Email: ${email}`);
    console.log(`Password: PeaceAdmin@2026`);
    console.log('-----------------------------------');
  }
}

createAdmin();
