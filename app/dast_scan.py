import time
import requests

def run_dast_scan():
    # Wait for app to be ready
    time.sleep(5)
    
    # Basic DAST checks
    try:
        response = requests.get('http://app:8080/')
        assert response.status_code == 200
        
        # Check for security headers
        headers = response.headers
        security_checks = [
            ('X-Content-Type-Options', 'nosniff'),
            ('X-Frame-Options', 'DENY'),
            ('X-XSS-Protection', '1; mode=block')
        ]
        
        for header, expected in security_checks:
            if header not in headers:
                print(f"Warning: Missing security header {header}")
                
        print("DAST scan completed successfully")
    except Exception as e:
        print(f"DAST scan failed: {e}")
        exit(1)

if __name__ == "__main__":
    run_dast_scan()
