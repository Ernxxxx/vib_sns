import { useState, useEffect } from 'react';
import { collection, query, orderBy, limit, getDocs } from 'firebase/firestore';
import { db } from '../services/firebase';
import { safeToDate } from '../utils/dateHelpers';

export interface Post {
  id: string;
  authorId: string;
  authorName: string;
  caption: string;
  createdAt: Date;
  likeCount: number;
  imageUrl?: string;
  imageBase64?: string;
  hashtags: string[];
  authorAvatarImageBase64?: string;
  authorColorValue?: number;
}

export const useAllPosts = (limitCount: number = 100, refreshKey: number = 0) => {
  const [posts, setPosts] = useState<Post[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let active = true;
    setLoading(true);

    const fetchPosts = async () => {
      try {
        const snapshot = await getDocs(
          query(
            collection(db, 'timelinePosts'),
            orderBy('createdAt', 'desc'),
            limit(limitCount)
          )
        );

        if (!active) {
          return;
        }

        const allPosts: Post[] = [];
        snapshot.forEach((doc) => {
          const data = doc.data();
          const createdAt = safeToDate(data.createdAt);

          if (createdAt) {
            const hashtagsRaw = data.hashtags;
            const hashtags = Array.isArray(hashtagsRaw)
              ? hashtagsRaw.map((tag: any) => tag.toString())
              : [];

            allPosts.push({
              id: doc.id || data.id || '',
              authorId: data.authorId || '',
              authorName: data.authorName || '不明なユーザー',
              caption: data.caption || '',
              createdAt: createdAt,
              likeCount: data.likeCount || 0,
              imageUrl: data.imageUrl,
              imageBase64: data.imageBase64,
              hashtags: hashtags,
              authorAvatarImageBase64: data.authorAvatarImageBase64,
              authorColorValue: data.authorColorValue,
            });
          }
        });

        allPosts.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
        setPosts(allPosts);
      } catch (error) {
        console.error('投稿取得に失敗:', error);
      } finally {
        if (active) {
          setLoading(false);
        }
      }
    };

    fetchPosts();

    return () => {
      active = false;
    };
  }, [limitCount, refreshKey]);

  return { posts, loading };
};

