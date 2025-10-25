import React, { useState } from 'react';
import { useCrossService } from './CrossServiceProvider';
import { useAuth } from '../../auth/AuthProvider';

interface ServiceNavigationMenuProps {
  position?: 'top' | 'bottom' | 'left' | 'right';
  variant?: 'dropdown' | 'sidebar' | 'tabs';
  showIcons?: boolean;
  showAvailabilityStatus?: boolean;
}

export const ServiceNavigationMenu: React.FC<ServiceNavigationMenuProps> = ({
  position = 'top',
  variant = 'dropdown',
  showIcons = true,
  showAvailabilityStatus = true
}) => {
  const { user } = useAuth();
  const { currentService, services, navigateToService, isServiceAvailable } = useCrossService();
  const [isOpen, setIsOpen] = useState(false);

  // Filter services based on user role
  const getAccessibleServices = () => {
    const userRole = user?.role || 'viewer';
    
    return Object.entries(services).filter(([serviceName, config]) => {
      switch (serviceName) {
        case 'admin-portal':
          return userRole === 'admin';
        case 'creator-dashboard':
          return ['creator', 'admin'].includes(userRole);
        case 'support-system':
          return ['support', 'admin'].includes(userRole);
        case 'analytics-dashboard':
          return ['analyst', 'admin', 'creator'].includes(userRole);
        case 'developer-console':
          return ['developer', 'admin'].includes(userRole);
        case 'viewer-portal':
          return true; // Available to all
        default:
          return true;
      }
    });
  };

  const accessibleServices = getAccessibleServices();

  const handleServiceNavigation = (serviceName: string) => {
    if (serviceName === currentService) {
      return; // Already on this service
    }
    
    navigateToService(serviceName, '', {
      previousService: currentService,
      navigationTimestamp: new Date().toISOString()
    });
    setIsOpen(false);
  };

  const getServiceStatusIndicator = (serviceName: string) => {
    if (!showAvailabilityStatus) return null;
    
    const isAvailable = isServiceAvailable(serviceName);
    return (
      <div className={`w-2 h-2 rounded-full ${isAvailable ? 'bg-green-400' : 'bg-red-400'}`} />
    );
  };

  const renderDropdownMenu = () => (
    <div className="relative">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex items-center space-x-2 px-4 py-2 bg-white border border-gray-300 rounded-md shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-blue-500"
      >
        <span>Services</span>
        <svg className={`w-4 h-4 transition-transform ${isOpen ? 'rotate-180' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
        </svg>
      </button>
      
      {isOpen && (
        <div className="absolute z-50 mt-2 w-64 bg-white border border-gray-200 rounded-md shadow-lg">
          <div className="py-1">
            {accessibleServices.map(([serviceName, config]) => (
              <button
                key={serviceName}
                onClick={() => handleServiceNavigation(serviceName)}
                disabled={serviceName === currentService}
                className={`w-full flex items-center justify-between px-4 py-2 text-left hover:bg-gray-100 ${
                  serviceName === currentService ? 'bg-blue-50 text-blue-700' : 'text-gray-700'
                }`}
              >
                <div className="flex items-center space-x-3">
                  {showIcons && <span className="text-lg">{config.icon}</span>}
                  <span className="font-medium">{config.name}</span>
                </div>
                <div className="flex items-center space-x-2">
                  {getServiceStatusIndicator(serviceName)}
                  {serviceName === currentService && (
                    <span className="text-xs text-blue-600">Current</span>
                  )}
                </div>
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );

  const renderTabsMenu = () => (
    <div className="flex space-x-1 bg-gray-100 p-1 rounded-lg">
      {accessibleServices.map(([serviceName, config]) => (
        <button
          key={serviceName}
          onClick={() => handleServiceNavigation(serviceName)}
          disabled={serviceName === currentService}
          className={`flex items-center space-x-2 px-3 py-2 rounded-md text-sm font-medium transition-colors ${
            serviceName === currentService
              ? 'bg-white text-blue-700 shadow-sm'
              : 'text-gray-600 hover:text-gray-900 hover:bg-gray-200'
          }`}
        >
          {showIcons && <span>{config.icon}</span>}
          <span>{config.name}</span>
          {getServiceStatusIndicator(serviceName)}
        </button>
      ))}
    </div>
  );

  const renderSidebarMenu = () => (
    <div className="w-64 bg-white border-r border-gray-200 h-full">
      <div className="p-4">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Services</h3>
        <nav className="space-y-2">
          {accessibleServices.map(([serviceName, config]) => (
            <button
              key={serviceName}
              onClick={() => handleServiceNavigation(serviceName)}
              disabled={serviceName === currentService}
              className={`w-full flex items-center justify-between p-3 rounded-lg text-left transition-colors ${
                serviceName === currentService
                  ? 'bg-blue-50 text-blue-700 border border-blue-200'
                  : 'text-gray-700 hover:bg-gray-100'
              }`}
            >
              <div className="flex items-center space-x-3">
                {showIcons && <span className="text-xl">{config.icon}</span>}
                <div>
                  <div className="font-medium">{config.name}</div>
                  {serviceName === currentService && (
                    <div className="text-xs text-blue-600">Current Service</div>
                  )}
                </div>
              </div>
              {getServiceStatusIndicator(serviceName)}
            </button>
          ))}
        </nav>
      </div>
    </div>
  );

  // Don't render if user has access to only one service
  if (accessibleServices.length <= 1) {
    return null;
  }

  switch (variant) {
    case 'dropdown':
      return renderDropdownMenu();
    case 'tabs':
      return renderTabsMenu();
    case 'sidebar':
      return renderSidebarMenu();
    default:
      return renderDropdownMenu();
  }
};

export default ServiceNavigationMenu;