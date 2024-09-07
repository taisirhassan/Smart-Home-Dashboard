import axios from 'axios';

const api = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL,
});

export interface DeviceData {
  device_id: string;
  device_type: string;
  timestamp: number;
  data: {
    data: any;
    temperature?: number;
    humidity?: number;
    status?: string;
    brightness?: number;
    motion_detected?: boolean;
    set_point?: number; // Added back set_point for thermostat
  };
}

export const fetchDeviceData = async (timeRange?: number): Promise<DeviceData[]> => {
  try {
    const response = await api.get<DeviceData[]>('/iot-data', {
      params: { timeRange: timeRange || 3600 } // Get data for the last hour by default
    });
    return response.data;
  } catch (error) {
    console.error('Error fetching device data:', error);
    throw error;
  }
};