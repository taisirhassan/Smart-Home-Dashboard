'use client'

import { useState, useEffect } from 'react'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts'
import { fetchDeviceData, DeviceData } from '../../utils/api'

export default function Home() {
  const [deviceData, setDeviceData] = useState<DeviceData[]>([])
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const fetchData = async () => {
      try {
        const data = await fetchDeviceData()
        console.log("Fetched data:", JSON.stringify(data, null, 2))
        setDeviceData(data)
        setError(null)
      } catch (error) {
        console.error('Error fetching device data:', error)
        setError('Failed to fetch device data. Please try again later.')
      }
    }

    fetchData()
    const interval = setInterval(fetchData, 5000) // Refresh every 5 seconds

    return () => clearInterval(interval)
  }, [])

  if (error) {
    return <div className="text-red-500 text-center mt-8 dashboard-text">{error}</div>
  }

  const temperatureData = deviceData.filter(device => 
    device.device_type === 'thermostat' && device.data.data.temperature !== undefined
  )

  return (
    <div className="space-y-8">
      <section className="dashboard-card">
        <h2 className="dashboard-subtitle mb-6">Device Overview</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {deviceData.map((device) => (
            <div key={device.device_id} className="bg-gray-50 rounded-lg p-4 shadow-sm hover:shadow-md transition duration-300">
              <h3 className="text-lg font-medium capitalize mb-2 text-gray-800">{device.device_type.replace('_', ' ')}</h3>
              <p className="text-sm text-gray-500 mb-3">ID: {device.device_id}</p>
              <div className="space-y-1 dashboard-text">
                {device.device_type === 'light' && (
                  <>
                    <p><span className="font-medium">Status:</span> {device.data.data.status || 'N/A'}</p>
                    <p><span className="font-medium">Brightness:</span> {device.data.data.brightness !== undefined ? `${device.data.data.brightness}%` : 'N/A'}</p>
                  </>
                )}
                {device.device_type === 'thermostat' && (
                  <>
                    <p><span className="font-medium">Temperature:</span> {device.data.data.temperature !== undefined ? `${device.data.data.temperature}°C` : 'N/A'}</p>
                    <p><span className="font-medium">Humidity:</span> {device.data.data.humidity !== undefined ? `${device.data.data.humidity}%` : 'N/A'}</p>
                    <p><span className="font-medium">Set Point:</span> {device.data.data.set_point !== undefined ? `${device.data.data.set_point}°C` : 'N/A'}</p>
                  </>
                )}
                {device.device_type === 'security_camera' && (
                  <>
                    <p><span className="font-medium">Status:</span> {device.data.data.status || 'N/A'}</p>
                    <p><span className="font-medium">Motion Detected:</span> {device.data.data.motion_detected !== undefined ? (device.data.data.motion_detected ? 'Yes' : 'No') : 'N/A'}</p>
                  </>
                )}
              </div>
              <p className="text-xs text-gray-400 mt-3">
                Last Updated: {new Date(device.timestamp).toLocaleString()}
              </p>
            </div>
          ))}
        </div>
      </section>

      <section className="dashboard-card">
        <h2 className="dashboard-subtitle mb-6">Temperature Over Time</h2>
        {temperatureData.length > 0 ? (
          <div className="h-80 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={temperatureData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis 
                  dataKey="timestamp" 
                  tickFormatter={(timestamp: number) => new Date(timestamp).toLocaleTimeString()} 
                  stroke="#4a5568"
                />
                <YAxis label={{ value: 'Temperature (°C)', angle: -90, position: 'insideLeft' }} stroke="#4a5568" />
                <Tooltip 
                  labelFormatter={(timestamp: number) => new Date(timestamp).toLocaleString()}
                  formatter={(value: number) => [`${value}°C`, 'Temperature']}
                  contentStyle={{ backgroundColor: 'rgba(255, 255, 255, 0.8)', borderRadius: '0.5rem', border: 'none', boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06)' }}
                />
                <Legend />
                <Line type="monotone" dataKey="data.data.temperature" stroke="#8884d8" strokeWidth={2} dot={{ r: 4 }} activeDot={{ r: 8 }} name="Temperature" />
              </LineChart>
            </ResponsiveContainer>
          </div>
        ) : (
          <p className="text-center text-gray-500 dashboard-text">No temperature data available</p>
        )}
      </section>
    </div>
  )
}