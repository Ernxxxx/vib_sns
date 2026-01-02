import React, { useEffect } from 'react';
import './BaseModal.css';

interface BaseModalProps {
  title: string;
  onClose: () => void;
  children: React.ReactNode;
  headerColor?: string;
}

export const BaseModal: React.FC<BaseModalProps> = ({
  title,
  onClose,
  children,
  headerColor = 'linear-gradient(135deg, #FFD54F 0%, #FFB74D 50%, #FF9800 100%)',
}) => {
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', handleEscape);
    document.body.style.overflow = 'hidden'; // 防止背景滚动
    
    return () => {
      document.removeEventListener('keydown', handleEscape);
      document.body.style.overflow = '';
    };
  }, [onClose]);

  return (
    <div className="base-modal-overlay" onClick={onClose}>
      <div className="base-modal" onClick={(e) => e.stopPropagation()}>
        <div 
          className="base-modal-header" 
          style={{ background: headerColor }}
        >
          <h2>{title}</h2>
          <button className="close-button" onClick={onClose} aria-label="关闭">
            ×
          </button>
        </div>
        <div className="base-modal-content">{children}</div>
      </div>
    </div>
  );
};

