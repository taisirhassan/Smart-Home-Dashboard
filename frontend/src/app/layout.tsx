import './globals.css'
import { Inter } from 'next/font/google'
import { FiHome } from 'react-icons/fi'

const inter = Inter({ subsets: ['latin'] })

export const metadata = {
  title: 'Smart Home Dashboard',
  description: 'Monitor and control your IoT devices',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en" className="h-full">
      <body className={`${inter.className} h-full flex flex-col`}>
        <header className="bg-indigo-600 text-white shadow-md">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="flex items-center justify-between h-16">
              <div className="flex-shrink-0 font-bold text-xl">Smart Home Dashboard</div>
              <nav>
                <a href="#" className="flex items-center px-3 py-2 rounded-md text-sm font-medium hover:bg-indigo-700 transition duration-150 ease-in-out">
                  <FiHome className="mr-2" /> Dashboard
                </a>
              </nav>
            </div>
          </div>
        </header>

        <main className="flex-grow bg-gray-100">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
            {children}
          </div>
        </main>

        <footer className="bg-indigo-600 text-white">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
            <div className="flex justify-between items-center">
              <p className="text-sm">&copy; 2023 Smart Home Dashboard. All rights reserved.</p>
              <div className="flex space-x-4">
                <a href="#" className="text-sm hover:text-indigo-200 transition duration-150 ease-in-out">Privacy Policy</a>
                <a href="#" className="text-sm hover:text-indigo-200 transition duration-150 ease-in-out">Terms of Service</a>
                <a href="#" className="text-sm hover:text-indigo-200 transition duration-150 ease-in-out">Contact Us</a>
              </div>
            </div>
          </div>
        </footer>
      </body>
    </html>
  )
}