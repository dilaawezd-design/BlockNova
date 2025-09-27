// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title BlockNova
 * @dev A decentralized innovation funding platform for blockchain projects
 */
contract Project {
    struct ProjectProposal {
        uint256 id;
        address creator;
        string title;
        string description;
        uint256 fundingGoal;
        uint256 totalFunded;
        uint256 deadline;
        bool isActive;
        bool fundsReleased;
    }
    
    struct Backer {
        address backerAddress;
        uint256 amount;
    }
    
    mapping(uint256 => ProjectProposal) public projects;
    mapping(uint256 => Backer[]) public projectBackers;
    mapping(uint256 => mapping(address => uint256)) public backerContributions;
    
    uint256 public projectCounter;
    address public owner;
    uint256 public platformFee = 2; // 2% platform fee
    
    event ProjectCreated(uint256 indexed projectId, address indexed creator, string title, uint256 fundingGoal);
    event ProjectFunded(uint256 indexed projectId, address indexed backer, uint256 amount);
    event FundsReleased(uint256 indexed projectId, address indexed creator, uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier validProject(uint256 _projectId) {
        require(_projectId > 0 && _projectId <= projectCounter, "Invalid project ID");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        projectCounter = 0;
    }
    
    /**
     * @dev Core Function 1: Submit a new project proposal
     * @param _title The title of the project
     * @param _description Detailed description of the project
     * @param _fundingGoal The funding goal in wei
     * @param _duration Duration of the funding period in seconds
     */
    function submitProject(
        string memory _title,
        string memory _description,
        uint256 _fundingGoal,
        uint256 _duration
    ) external {
        require(bytes(_title).length > 0, "Project title cannot be empty");
        require(_fundingGoal > 0, "Funding goal must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");
        
        projectCounter++;
        
        projects[projectCounter] = ProjectProposal({
            id: projectCounter,
            creator: msg.sender,
            title: _title,
            description: _description,
            fundingGoal: _fundingGoal,
            totalFunded: 0,
            deadline: block.timestamp + _duration,
            isActive: true,
            fundsReleased: false
        });
        
        emit ProjectCreated(projectCounter, msg.sender, _title, _fundingGoal);
    }
    
    /**
     * @dev Core Function 2: Fund a project
     * @param _projectId The ID of the project to fund
     */
    function fundProject(uint256 _projectId) external payable validProject(_projectId) {
        ProjectProposal storage project = projects[_projectId];
        
        require(project.isActive, "Project is not active");
        require(block.timestamp < project.deadline, "Funding period has ended");
        require(msg.value > 0, "Funding amount must be greater than 0");
        require(project.totalFunded < project.fundingGoal, "Project already fully funded");
        
        // Update backer contribution
        backerContributions[_projectId][msg.sender] += msg.value;
        
        // Add to backers list if first contribution
        if (backerContributions[_projectId][msg.sender] == msg.value) {
            projectBackers[_projectId].push(Backer({
                backerAddress: msg.sender,
                amount: msg.value
            }));
        } else {
            // Update existing backer amount
            Backer[] storage backers = projectBackers[_projectId];
            for (uint i = 0; i < backers.length; i++) {
                if (backers[i].backerAddress == msg.sender) {
                    backers[i].amount += msg.value;
                    break;
                }
            }
        }
        
        project.totalFunded += msg.value;
        
        emit ProjectFunded(_projectId, msg.sender, msg.value);
        
        // Auto-release funds if goal is reached
        if (project.totalFunded >= project.fundingGoal) {
            releaseFunds(_projectId);
        }
    }
    
    /**
     * @dev Core Function 3: Release funds to project creator
     * @param _projectId The ID of the project
     */
    function releaseFunds(uint256 _projectId) public validProject(_projectId) {
        ProjectProposal storage project = projects[_projectId];
        
        require(project.isActive, "Project is not active");
        require(!project.fundsReleased, "Funds already released");
        require(
            project.totalFunded >= project.fundingGoal || block.timestamp >= project.deadline,
            "Funding goal not met or deadline not reached"
        );
        
        uint256 totalAmount = project.totalFunded;
        uint256 platformFeeAmount = (totalAmount * platformFee) / 100;
        uint256 creatorAmount = totalAmount - platformFeeAmount;
        
        project.fundsReleased = true;
        project.isActive = false;
        
        // Transfer funds to creator
        payable(project.creator).transfer(creatorAmount);
        
        // Transfer platform fee to owner
        payable(owner).transfer(platformFeeAmount);
        
        emit FundsReleased(_projectId, project.creator, creatorAmount);
    }
    
    // View functions
    function getProject(uint256 _projectId) external view validProject(_projectId) returns (ProjectProposal memory) {
        return projects[_projectId];
    }
    
    function getProjectBackers(uint256 _projectId) external view validProject(_projectId) returns (Backer[] memory) {
        return projectBackers[_projectId];
    }
    
    function getBackerContribution(uint256 _projectId, address _backer) external view returns (uint256) {
        return backerContributions[_projectId][_backer];
    }
    
    // Owner functions
    function updatePlatformFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 10, "Platform fee cannot exceed 10%");
        platformFee = _newFee;
    }
    
    function withdrawPlatformFees() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
