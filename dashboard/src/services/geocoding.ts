/**
 * 地理编码服务 - 将经纬度转换为日文地址
 * 使用OpenStreetMap Nominatim API（免费，无需API key）
 */

interface GeocodingResult {
  address: string | null;
  error?: string;
}

// 缓存结果以避免重复请求
const addressCache = new Map<string, { address: string | null; timestamp: number }>();
const CACHE_DURATION_MS = 24 * 60 * 60 * 1000; // 24小时缓存

/**
 * 从Nominatim响应中提取区名（如"渋谷区"）
 */
function extractWardName(components: any): string | null {
  if (!components) return null;

  // 优先顺序：区 > 市 > 町
  if (components.ward) return components.ward;
  if (components.city) return components.city;
  if (components.town) return components.town;
  if (components.village) return components.village;
  
  // 如果都没有，尝试从address中提取
  const address = components.address || '';
  const wardMatch = address.match(/(.+?区)/);
  if (wardMatch) return wardMatch[1];
  
  return null;
}

/**
 * 将经纬度转换为日文地址（区名）
 * @param lat 纬度
 * @param lng 经度
 * @returns 区名（如"渋谷区"），失败时返回null
 */
export async function reverseGeocode(lat: number, lng: number): Promise<GeocodingResult> {
  // 创建缓存键（四舍五入到小数点后3位以减少缓存条目）
  const cacheKey = `${lat.toFixed(3)},${lng.toFixed(3)}`;
  
  // 检查缓存
  const cached = addressCache.get(cacheKey);
  if (cached && Date.now() - cached.timestamp < CACHE_DURATION_MS) {
    return { address: cached.address };
  }

  try {
    // 使用Nominatim API进行逆地理编码
    // 添加延迟以避免超过速率限制（每秒1个请求）
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    const url = `https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lng}&accept-language=ja`;
    
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'VIB-SNS-Dashboard/1.0', // Nominatim要求User-Agent
      },
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const data = await response.json();
    
    if (data.error) {
      throw new Error(data.error);
    }

    // 提取区名
    let address: string | null = null;
    
    if (data.address) {
      address = extractWardName(data.address);
    }

    if (!address && data.display_name) {
      const match = data.display_name.match(/(.+?[市区町村])/);
      if (match) {
        address = match[1];
      }
    }

    // 缓存结果
    addressCache.set(cacheKey, { address, timestamp: Date.now() });
    
    return { address };
  } catch (error) {
    console.warn('逆地理编码に失敗:', error, { lat, lng });
    // 即使失败也缓存null结果，避免重复请求
    addressCache.set(cacheKey, { address: null, timestamp: Date.now() });
    return { address: null, error: error instanceof Error ? error.message : 'Unknown error' };
  }
}

/**
 * 批量逆地理编码（带速率限制）
 */
export async function reverseGeocodeBatch(
  coordinates: Array<{ lat: number; lng: number }>
): Promise<Map<string, string | null>> {
  const results = new Map<string, string | null>();
  
  for (const coord of coordinates) {
    const key = `${coord.lat},${coord.lng}`;
    const result = await reverseGeocode(coord.lat, coord.lng);
    results.set(key, result.address);
  }
  
  return results;
}

