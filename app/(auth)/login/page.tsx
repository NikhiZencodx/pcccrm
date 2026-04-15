'use client'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card } from '@/components/ui/card'
import { createClient } from '@/lib/supabase/client'
import { toast } from 'sonner'
import Image from 'next/image'

const loginSchema = z.object({
  email: z.string().email('Valid email required'),
  password: z.string().min(6, 'Password must be at least 6 characters'),
})

type LoginFormData = z.infer<typeof loginSchema>

export default function LoginPage() {
  const [loading, setLoading] = useState(false)
  const supabase = createClient()

  const { register, handleSubmit, formState: { errors } } = useForm<LoginFormData>({
    resolver: zodResolver(loginSchema),
  })

  async function onSubmit(data: LoginFormData) {
    setLoading(true)
    try {
      const { error } = await supabase.auth.signInWithPassword({
        email: data.email,
        password: data.password,
      })
      if (error) {
        toast.error(error.message)
        return
      }
      window.location.replace('/dashboard')
    } catch {
      toast.error('Something went wrong')
    } finally {
      setLoading(false)
    }
  }


  return (
    <Card className="w-full max-w-5xl shadow-2xl overflow-hidden border-none mx-4">
      <div className="flex flex-col md:flex-row min-h-[600px]">
        {/* Left Side - Brand & Visuals */}
        <div className="w-full md:w-5/12 bg-green-700 p-12 text-white flex flex-col justify-between relative overflow-hidden hidden md:flex">
          <div className="absolute inset-0 bg-gradient-to-br from-green-800 to-emerald-900 opacity-90 z-0"></div>

          <div className="relative z-10 flex flex-col h-full">
            <div className="flex flex-col items-center gap-3 mb-12">
              <div className="w-24 h-24 rounded-full bg-white/10 border-2 border-white/30 shadow-xl flex items-center justify-center p-1">
                <Image src="/brand-logo.png" alt="Peace Career Consultancy Logo" width={88} height={88} className="w-full h-full object-contain rounded-full" priority />
              </div>
              <div className="text-center">
                <h1 className="text-2xl font-bold tracking-tight leading-tight">Peace Career</h1>
                <p className="text-green-300 text-sm font-semibold uppercase tracking-widest mt-0.5">Consultancy</p>
              </div>
            </div>

            <div className="flex-grow flex flex-col justify-center">
              <h2 className="text-4xl font-extrabold mb-6 leading-tight">
                Manage your <br /> institution <br /> with ease.
              </h2>
              <p className="text-green-100 text-lg max-w-md">
                The all-in-one education consultancy management system designed to streamline admissions and boost productivity.
              </p>
            </div>
          </div>

          <div className="relative z-10 mt-12 bg-white/10 p-6 rounded-2xl backdrop-blur-md border border-white/20 shadow-lg">
            <p className="italic text-green-50 text-sm">
              "Peace Career Consultancy has transformed how we handle our student management. Highly recommended platform!"
            </p>
            <div className="mt-4 flex items-center gap-3">
              <div className="w-10 h-10 bg-gradient-to-tr from-green-400 to-green-300 rounded-full flex items-center justify-center font-bold text-white shadow-sm border border-white/10">
                SR
              </div>
              <div>
                <p className="font-semibold text-sm">Sarah Richards</p>
                <p className="text-green-200 text-xs text-opacity-90">Director of Admissions</p>
              </div>
            </div>
          </div>

          {/* Decorative Elements */}
          <div className="absolute -bottom-24 -left-24 w-64 h-64 bg-green-600 rounded-full mix-blend-multiply filter blur-3xl opacity-50 z-0 animate-pulse"></div>
          <div className="absolute top-1/4 -right-24 w-64 h-64 bg-emerald-500 rounded-full mix-blend-multiply filter blur-3xl opacity-50 z-0"></div>
        </div>

        {/* Right Side - Login Form */}
        <div className="w-full md:w-7/12 p-8 md:p-16 bg-white flex flex-col justify-center relative">
          {/* Mobile Header (Hidden on Desktop) */}
          <div className="flex md:hidden flex-col items-center gap-2 mb-8">
            <div className="w-16 h-16 rounded-full bg-green-50 border-2 border-green-200 shadow-md flex items-center justify-center p-1">
              <Image src="/brand-logo.png" alt="Peace Career Consultancy Logo" width={56} height={56} className="w-full h-full object-contain rounded-full" />
            </div>
            <h1 className="text-xl font-bold tracking-tight text-gray-900 text-center">Peace Career Consultancy</h1>
          </div>

          <div className="max-w-md w-full mx-auto space-y-8">
            <div className="text-center md:text-left">
              <h3 className="text-3xl font-bold text-gray-900 tracking-tight">Welcome back</h3>
              <p className="text-gray-500 mt-2 text-sm">Please enter your details to sign in.</p>
            </div>


            <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
              <div className="space-y-2">
                <Label htmlFor="email" className="text-sm font-medium text-gray-700">Email Address</Label>
                <Input
                  id="email"
                  type="email"
                  placeholder="name@company.com"
                  className="rounded-xl h-11 border-gray-300 focus:border-green-600 focus:ring-green-600 transition-shadow"
                  {...register('email')}
                  autoComplete="email"
                />
                {errors.email && <p className="text-xs text-red-500 mt-1">{errors.email.message}</p>}
              </div>
              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <Label htmlFor="password" className="text-sm font-medium text-gray-700">Password</Label>
                  <a href="#" className="text-sm font-medium text-green-700 hover:text-green-800 transition-colors">
                    Forgot password?
                  </a>
                </div>
                <Input
                  id="password"
                  type="password"
                  placeholder="••••••••"
                  className="rounded-xl h-11 border-gray-300 focus:border-green-600 focus:ring-green-600 transition-shadow"
                  {...register('password')}
                  autoComplete="current-password"
                />
                {errors.password && <p className="text-xs text-red-500 mt-1">{errors.password.message}</p>}
              </div>

              <div className="flex items-center">
                <input
                  id="remember-me"
                  name="remember-me"
                  type="checkbox"
                  className="h-4 w-4 text-green-700 focus:ring-green-600 border-gray-300 rounded cursor-pointer transition-colors"
                />
                <label htmlFor="remember-me" className="ml-2 block text-sm text-gray-700 cursor-pointer">
                  Remember me for 30 days
                </label>
              </div>

              <Button type="submit" className="w-full rounded-xl h-11 shadow-md bg-gray-900 hover:bg-black text-white transition-all font-semibold" disabled={loading}>
                {loading ? (
                  <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                ) : (
                  'Sign in'
                )}
              </Button>
            </form>

            <p className="text-center text-sm text-gray-500 mt-8">
              Developed by{' '}
              <a href="https://blinks-ai.com" target="_blank" rel="noopener noreferrer" className="font-semibold text-green-700 hover:text-green-800 transition-colors">
                Blinks AI
              </a>
            </p>
          </div>
        </div>
      </div>
    </Card>
  )
}
