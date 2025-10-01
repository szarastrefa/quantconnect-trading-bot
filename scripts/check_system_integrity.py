#!/usr/bin/env python3
"""
System Integrity Check Script for QuantConnect Trading Bot
Performs comprehensive validation of all system components
"""

import os
import sys
import json
import subprocess
import importlib
from pathlib import Path
from typing import Dict, List, Tuple, Any
from datetime import datetime
import requests
import yaml

class SystemIntegrityChecker:
    def __init__(self, project_root: str = None):
        self.project_root = Path(project_root or os.getcwd())
        self.issues = []
        self.warnings = []
        self.passed_checks = []
        
        # Define expected file structure
        self.expected_structure = {
            'root': {
                'files': ['docker-compose.yml', 'README.md'],
                'directories': ['backend', 'frontend', 'docs']
            },
            'backend': {
                'files': ['app.py', 'requirements.txt', 'Dockerfile'],
                'directories': ['api', 'services', 'models', 'utils']
            },
            'backend/services': {
                'files': ['broker_service.py', 'ml_service.py', 'lean_service.py']
            },
            'backend/api': {
                'files': ['routes.py']
            },
            'frontend': {
                'files': ['package.json']
            },
            'docs': {
                'files': ['BROKER_WORKFLOWS.md']
            }
        }
        
        self.critical_dependencies = {
            'backend': [
                'flask', 'flask-cors', 'flask-sqlalchemy', 'flask-socketio',
                'redis', 'psycopg2-binary', 'pandas', 'numpy', 'scikit-learn',
                'ccxt', 'MetaTrader5', 'requests'
            ],
            'frontend': [
                'react', 'react-dom', 'axios', 'socket.io-client'
            ]
        }

    def run_full_check(self) -> Dict[str, Any]:
        """Run comprehensive system integrity check"""
        print("🔍 Starting QuantConnect Trading Bot System Integrity Check...\n")
        
        # File structure checks
        self._check_file_structure()
        
        # Configuration checks
        self._check_docker_configuration()
        
        # Backend checks
        self._check_backend_integrity()
        
        # Frontend checks
        self._check_frontend_integrity()
        
        # Service integration checks
        self._check_service_integrations()
        
        # Documentation checks
        self._check_documentation()
        
        # Security checks
        self._check_security_configurations()
        
        # Performance checks
        self._check_performance_configurations()
        
        # Generate report
        return self._generate_report()

    def _check_file_structure(self):
        """Check if all expected files and directories exist"""
        print("📁 Checking file structure...")
        
        for path_key, structure in self.expected_structure.items():
            base_path = self.project_root
            if path_key != 'root':
                base_path = self.project_root / path_key
            
            # Check if base path exists
            if not base_path.exists():
                self.issues.append(f"Missing directory: {path_key}")
                continue
            
            # Check required files
            for file_name in structure.get('files', []):
                file_path = base_path / file_name
                if not file_path.exists():
                    self.issues.append(f"Missing file: {path_key}/{file_name}")
                else:
                    self.passed_checks.append(f"✅ File exists: {path_key}/{file_name}")
            
            # Check required directories
            for dir_name in structure.get('directories', []):
                dir_path = base_path / dir_name
                if not dir_path.exists():
                    self.issues.append(f"Missing directory: {path_key}/{dir_name}")
                else:
                    self.passed_checks.append(f"✅ Directory exists: {path_key}/{dir_name}")

    def _check_docker_configuration(self):
        """Check Docker configuration integrity"""
        print("🐳 Checking Docker configuration...")
        
        docker_compose_path = self.project_root / 'docker-compose.yml'
        
        if not docker_compose_path.exists():
            self.issues.append("Missing docker-compose.yml")
            return
        
        try:
            with open(docker_compose_path, 'r') as f:
                docker_config = yaml.safe_load(f)
            
            # Check required services
            required_services = ['api', 'db', 'redis', 'lean_engine']
            services = docker_config.get('services', {})
            
            for service in required_services:
                if service not in services:
                    self.issues.append(f"Missing Docker service: {service}")
                else:
                    self.passed_checks.append(f"✅ Docker service configured: {service}")
            
            # Check volumes
            volumes = docker_config.get('volumes', {})
            required_volumes = ['postgres_data', 'redis_data']
            
            for volume in required_volumes:
                if volume not in volumes:
                    self.issues.append(f"Missing Docker volume: {volume}")
                else:
                    self.passed_checks.append(f"✅ Docker volume configured: {volume}")
            
            # Check networks
            networks = docker_config.get('networks', {})
            if 'trading_network' not in networks:
                self.issues.append("Missing trading_network in Docker configuration")
            else:
                self.passed_checks.append("✅ Docker network configured: trading_network")
                
        except Exception as e:
            self.issues.append(f"Invalid docker-compose.yml: {str(e)}")

    def _check_backend_integrity(self):
        """Check backend code integrity"""
        print("🔧 Checking backend integrity...")
        
        backend_path = self.project_root / 'backend'
        
        # Check main application file
        app_py_path = backend_path / 'app.py'
        if app_py_path.exists():
            self._check_python_syntax(app_py_path)
            self._check_flask_app_structure(app_py_path)
        
        # Check requirements.txt
        req_path = backend_path / 'requirements.txt'
        if req_path.exists():
            self._check_requirements(req_path)
        
        # Check service files
        services_path = backend_path / 'services'
        if services_path.exists():
            for service_file in ['broker_service.py', 'ml_service.py', 'lean_service.py']:
                service_path = services_path / service_file
                if service_path.exists():
                    self._check_python_syntax(service_path)
                    self.passed_checks.append(f"✅ Service file syntax valid: {service_file}")
        
        # Check API routes
        api_path = backend_path / 'api' / 'routes.py'
        if api_path.exists():
            self._check_python_syntax(api_path)
            self._check_api_routes_structure(api_path)

    def _check_frontend_integrity(self):
        """Check frontend integrity"""
        print("⚛️ Checking frontend integrity...")
        
        frontend_path = self.project_root / 'frontend'
        package_json_path = frontend_path / 'package.json'
        
        if package_json_path.exists():
            try:
                with open(package_json_path, 'r') as f:
                    package_data = json.load(f)
                
                # Check critical dependencies
                dependencies = package_data.get('dependencies', {})
                dev_dependencies = package_data.get('devDependencies', {})
                all_deps = {**dependencies, **dev_dependencies}
                
                for dep in self.critical_dependencies['frontend']:
                    if dep in all_deps:
                        self.passed_checks.append(f"✅ Frontend dependency: {dep}")
                    else:
                        self.issues.append(f"Missing frontend dependency: {dep}")
                
                # Check scripts
                scripts = package_data.get('scripts', {})
                required_scripts = ['start', 'build']
                
                for script in required_scripts:
                    if script in scripts:
                        self.passed_checks.append(f"✅ Frontend script: {script}")
                    else:
                        self.warnings.append(f"Missing frontend script: {script}")
                        
            except Exception as e:
                self.issues.append(f"Invalid package.json: {str(e)}")

    def _check_service_integrations(self):
        """Check service integration points"""
        print("🔗 Checking service integrations...")
        
        # Check if services are properly imported in main app
        app_py_path = self.project_root / 'backend' / 'app.py'
        if app_py_path.exists():
            try:
                with open(app_py_path, 'r') as f:
                    app_content = f.read()
                
                required_imports = [
                    'from services.lean_service import LeanService',
                    'from services.broker_service import BrokerService',
                    'from services.ml_service import MLService'
                ]
                
                for import_stmt in required_imports:
                    if import_stmt in app_content:
                        self.passed_checks.append(f"✅ Service import: {import_stmt.split()[-1]}")
                    else:
                        self.issues.append(f"Missing service import: {import_stmt}")
                
                # Check WebSocket configuration
                if 'SocketIO' in app_content and 'socketio.run' in app_content:
                    self.passed_checks.append("✅ WebSocket integration configured")
                else:
                    self.warnings.append("WebSocket integration may not be properly configured")
                    
            except Exception as e:
                self.issues.append(f"Error checking app.py integrations: {str(e)}")

    def _check_documentation(self):
        """Check documentation completeness"""
        print("📚 Checking documentation...")
        
        docs_path = self.project_root / 'docs'
        
        # Check broker workflows documentation
        broker_workflows_path = docs_path / 'BROKER_WORKFLOWS.md'
        if broker_workflows_path.exists():
            try:
                with open(broker_workflows_path, 'r') as f:
                    content = f.read()
                
                # Check for key sections
                required_sections = [
                    '# Broker Integration Workflows',
                    '## Forex/CFD Brokers',
                    '## Cryptocurrency Exchanges',
                    'XM', 'Binance', 'Kraken'
                ]
                
                for section in required_sections:
                    if section in content:
                        self.passed_checks.append(f"✅ Documentation section: {section}")
                    else:
                        self.warnings.append(f"Missing documentation section: {section}")
                        
            except Exception as e:
                self.issues.append(f"Error reading broker workflows documentation: {str(e)}")
        
        # Check README
        readme_path = self.project_root / 'README.md'
        if readme_path.exists():
            self.passed_checks.append("✅ README.md exists")
        else:
            self.warnings.append("README.md is missing or incomplete")

    def _check_security_configurations(self):
        """Check security configurations"""
        print("🔐 Checking security configurations...")
        
        # Check for hardcoded secrets in docker-compose
        docker_compose_path = self.project_root / 'docker-compose.yml'
        if docker_compose_path.exists():
            with open(docker_compose_path, 'r') as f:
                content = f.read()
            
            # Check for environment variables
            if '${POSTGRES_PASSWORD' in content:
                self.passed_checks.append("✅ Database password uses environment variable")
            else:
                self.issues.append("Database password should use environment variable")
            
            if '${SECRET_KEY' in content:
                self.passed_checks.append("✅ Secret key uses environment variable")
            else:
                self.issues.append("Secret key should use environment variable")
        
        # Check for .env.example file
        env_example_path = self.project_root / '.env.example'
        if env_example_path.exists():
            self.passed_checks.append("✅ Environment example file exists")
        else:
            self.warnings.append("Consider adding .env.example file")
        
        # Check .gitignore
        gitignore_path = self.project_root / '.gitignore'
        if gitignore_path.exists():
            with open(gitignore_path, 'r') as f:
                gitignore_content = f.read()
            
            security_patterns = ['.env', '*.key', '*.pem', '__pycache__']
            for pattern in security_patterns:
                if pattern in gitignore_content:
                    self.passed_checks.append(f"✅ Gitignore includes: {pattern}")
                else:
                    self.warnings.append(f"Consider adding to .gitignore: {pattern}")

    def _check_performance_configurations(self):
        """Check performance-related configurations"""
        print("⚡ Checking performance configurations...")
        
        # Check Docker configurations for performance
        docker_compose_path = self.project_root / 'docker-compose.yml'
        if docker_compose_path.exists():
            with open(docker_compose_path, 'r') as f:
                content = f.read()
            
            # Check for restart policies
            if 'restart: unless-stopped' in content:
                self.passed_checks.append("✅ Docker restart policies configured")
            else:
                self.warnings.append("Consider adding restart policies to Docker services")
            
            # Check for volume mounts
            if 'volumes:' in content:
                self.passed_checks.append("✅ Docker volumes configured for data persistence")
            
            # Check for Redis persistence
            if 'redis-server --appendonly yes' in content:
                self.passed_checks.append("✅ Redis persistence enabled")
            else:
                self.warnings.append("Consider enabling Redis persistence")

    def _check_python_syntax(self, file_path: Path):
        """Check Python file syntax"""
        try:
            with open(file_path, 'r') as f:
                content = f.read()
            compile(content, str(file_path), 'exec')
            return True
        except SyntaxError as e:
            self.issues.append(f"Syntax error in {file_path}: {str(e)}")
            return False
        except Exception as e:
            self.warnings.append(f"Could not check syntax for {file_path}: {str(e)}")
            return False

    def _check_flask_app_structure(self, app_path: Path):
        """Check Flask app structure"""
        try:
            with open(app_path, 'r') as f:
                content = f.read()
            
            # Check for Flask app creation
            if 'Flask(__name__)' in content:
                self.passed_checks.append("✅ Flask app properly initialized")
            else:
                self.issues.append("Flask app initialization not found")
            
            # Check for SocketIO
            if 'SocketIO' in content:
                self.passed_checks.append("✅ SocketIO integration found")
            else:
                self.warnings.append("SocketIO integration not found")
            
            # Check for database initialization
            if 'SQLAlchemy' in content:
                self.passed_checks.append("✅ Database integration found")
            else:
                self.issues.append("Database integration not found")
                
        except Exception as e:
            self.issues.append(f"Error checking Flask app structure: {str(e)}")

    def _check_api_routes_structure(self, routes_path: Path):
        """Check API routes structure"""
        try:
            with open(routes_path, 'r') as f:
                content = f.read()
            
            # Check for critical API endpoints
            critical_endpoints = [
                '@api_bp.route(\'/', status\'')',
                '@api_bp.route(\'/brokers\'')',
                '@api_bp.route(\'/models\'')',
                '@api_bp.route(\'/signals\'')'
            ]
            
            for endpoint in critical_endpoints:
                if endpoint.replace('\\\'', '\'') in content.replace('\\\'', '\''):
                    self.passed_checks.append(f"✅ API endpoint: {endpoint.split('/')[1].split('\'')[0]}")
            
            # Check for error handlers
            if '@api_bp.errorhandler' in content:
                self.passed_checks.append("✅ API error handlers configured")
            else:
                self.warnings.append("Consider adding API error handlers")
                
        except Exception as e:
            self.issues.append(f"Error checking API routes: {str(e)}")

    def _check_requirements(self, req_path: Path):
        """Check Python requirements"""
        try:
            with open(req_path, 'r') as f:
                requirements = f.read().lower()
            
            # Check critical dependencies
            for dep in self.critical_dependencies['backend']:
                if dep.lower() in requirements:
                    self.passed_checks.append(f"✅ Backend dependency: {dep}")
                else:
                    self.issues.append(f"Missing backend dependency: {dep}")
                    
        except Exception as e:
            self.issues.append(f"Error checking requirements: {str(e)}")

    def _generate_report(self) -> Dict[str, Any]:
        """Generate comprehensive integrity report"""
        total_checks = len(self.passed_checks) + len(self.issues) + len(self.warnings)
        
        report = {
            'timestamp': datetime.now().isoformat(),
            'summary': {
                'total_checks': total_checks,
                'passed': len(self.passed_checks),
                'issues': len(self.issues),
                'warnings': len(self.warnings),
                'health_score': round((len(self.passed_checks) / total_checks) * 100, 1) if total_checks > 0 else 0
            },
            'passed_checks': self.passed_checks,
            'issues': self.issues,
            'warnings': self.warnings,
            'recommendations': self._generate_recommendations()
        }
        
        self._print_report(report)
        return report

    def _generate_recommendations(self) -> List[str]:
        """Generate recommendations based on findings"""
        recommendations = []
        
        if self.issues:
            recommendations.append("🚨 Fix all critical issues before deployment")
            
        if len(self.warnings) > 5:
            recommendations.append("⚠️ Review and address warnings to improve system stability")
            
        if not any('✅ Environment example file exists' in check for check in self.passed_checks):
            recommendations.append("📄 Create .env.example file with configuration templates")
            
        if not any('✅ Docker' in check for check in self.passed_checks):
            recommendations.append("🐳 Ensure Docker configuration is complete and tested")
            
        if len(self.passed_checks) < 20:
            recommendations.append("🔧 Consider adding more comprehensive tests and checks")
            
        return recommendations

    def _print_report(self, report: Dict[str, Any]):
        """Print formatted integrity report"""
        print("\n" + "="*80)
        print("🏁 SYSTEM INTEGRITY CHECK COMPLETE")
        print("="*80)
        
        summary = report['summary']
        print(f"\n📊 SUMMARY:")
        print(f"   Total Checks: {summary['total_checks']}")
        print(f"   ✅ Passed: {summary['passed']}")
        print(f"   ❌ Issues: {summary['issues']}")
        print(f"   ⚠️  Warnings: {summary['warnings']}")
        print(f"   🎯 Health Score: {summary['health_score']}%")
        
        # Health status
        if summary['health_score'] >= 90:
            print("\n🟢 SYSTEM STATUS: EXCELLENT")
        elif summary['health_score'] >= 75:
            print("\n🟡 SYSTEM STATUS: GOOD (some improvements needed)")
        elif summary['health_score'] >= 50:
            print("\n🟠 SYSTEM STATUS: FAIR (several issues need attention)")
        else:
            print("\n🔴 SYSTEM STATUS: POOR (critical issues require immediate attention)")
        
        # Issues
        if report['issues']:
            print(f"\n❌ CRITICAL ISSUES ({len(report['issues'])}):")
            for i, issue in enumerate(report['issues'][:10], 1):
                print(f"   {i}. {issue}")
            if len(report['issues']) > 10:
                print(f"   ... and {len(report['issues']) - 10} more")
        
        # Warnings
        if report['warnings']:
            print(f"\n⚠️  WARNINGS ({len(report['warnings'])}):")
            for i, warning in enumerate(report['warnings'][:5], 1):
                print(f"   {i}. {warning}")
            if len(report['warnings']) > 5:
                print(f"   ... and {len(report['warnings']) - 5} more")
        
        # Recommendations
        if report['recommendations']:
            print(f"\n💡 RECOMMENDATIONS:")
            for i, rec in enumerate(report['recommendations'], 1):
                print(f"   {i}. {rec}")
        
        print("\n" + "="*80)
        
        # Quick start guide if issues found
        if report['issues'] or len(report['warnings']) > 3:
            print("\n🚀 QUICK FIX GUIDE:")
            print("   1. Review and fix critical issues listed above")
            print("   2. Run 'docker-compose build' to test container builds")
            print("   3. Check all environment variables are properly set")
            print("   4. Verify all service dependencies are available")
            print("   5. Re-run this integrity check after fixes")
        else:
            print("\n🎉 System appears healthy! Ready for deployment.")
            print("\n🚀 NEXT STEPS:")
            print("   1. Set up environment variables (.env file)")
            print("   2. Run 'docker-compose up' to start the system")
            print("   3. Test broker connections and ML model imports")
            print("   4. Access the web UI at http://localhost:3000")

def main():
    """Main function to run system integrity check"""
    import argparse
    
    parser = argparse.ArgumentParser(description='QuantConnect Trading Bot System Integrity Check')
    parser.add_argument('--project-root', default='.', help='Project root directory')
    parser.add_argument('--output', help='Output file for detailed report (JSON)')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose output')
    
    args = parser.parse_args()
    
    # Initialize and run checker
    checker = SystemIntegrityChecker(args.project_root)
    report = checker.run_full_check()
    
    # Save detailed report if requested
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(report, f, indent=2)
        print(f"\n💾 Detailed report saved to: {args.output}")
    
    # Exit with appropriate code
    if report['summary']['issues'] > 0:
        sys.exit(1)  # Critical issues found
    elif report['summary']['warnings'] > 10:
        sys.exit(2)  # Too many warnings
    else:
        sys.exit(0)  # All good

if __name__ == '__main__':
    main()