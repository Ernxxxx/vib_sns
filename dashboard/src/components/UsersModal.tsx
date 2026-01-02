import React from 'react';
import { BaseModal } from './BaseModal';
import { AllUsersList } from './AllUsersList';
import { AllUser } from '../hooks/useAllUsers';

interface UsersModalProps {
  users: AllUser[];
  loading: boolean;
  error?: string | null;
  onClose: () => void;
}

export const UsersModal: React.FC<UsersModalProps> = ({ 
  users, 
  loading, 
  error, 
  onClose 
}) => {
  const onlineCount = users.filter(u => u.isOnline).length;
  const totalCount = users.length;
  
  return (
    <BaseModal 
      title={`👥 全ユーザー (${onlineCount}/${totalCount})`}
      onClose={onClose}
      headerColor="linear-gradient(135deg, #FFD54F 0%, #FFB74D 50%, #FF9800 100%)"
    >
      <AllUsersList users={users} loading={loading} error={error} />
    </BaseModal>
  );
};

